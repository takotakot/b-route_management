package instant2bq

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
	"github.com/google/uuid"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/pubsub"
)

const UUID_RETRY_MAX = 10

// const CONCURRENT_MESSAGES = 512

const CONCURRENT_MESSAGES = 4096

// Script variable insert_values exceeded the size limit of 1048576 bytes at [1:1]
// const CONCURRENT_MESSAGES = 8192

const RECEIVE_MESSAGES_THRESHOLD = 16

// const CONCURRENT_MESSAGES = 2
const EPOCH_2K = 946684800
const JST_DIFF = 9 * 60 * 60
const debug = false
const functionTimeout = 290 * time.Second

var (
	receivedMessages  = make(map[string]*pubsub.Message)
	preparingMessages = make(map[string]*pubsub.Message)
	sending           = make(map[string]struct{})
	processResults    = make(map[string]int)
	resultChans       = make(map[string]chan int)
	mu                sync.Mutex
	projectID         string
	subscriptionID    string
	JST               = time.FixedZone("Asia/Tokyo", JST_DIFF)
	pullMsgsSyncFunc  = pullMsgsSync
)

type InstantData struct {
	PointID            string
	Timestamp          time.Time
	InstantaneousPower int64
}

func init() {
	functions.HTTP("instant2bq", handler)
}

func handler(w http.ResponseWriter, r *http.Request) {
	projectID = os.Getenv("PROJECT_ID")
	subscriptionID = os.Getenv("SUBSCRIPTION_ID")

	if projectID == "" || subscriptionID == "" {
		http.Error(w, "Missing project ID or subscription ID", http.StatusBadRequest)
		return
	}

	err := pullMsgsSyncFunc(w, projectID, subscriptionID)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to pull messages: %v", err), http.StatusInternalServerError)
		return
	}

	fmt.Fprintln(w, "Messages pulled and processed successfully")
}

// NewMessageHandler returns a message handler function
func NewMessageHandler(m *sync.Map, processFunc func(ctx context.Context, msg *pubsub.Message, uuid *uuid.UUID) error) func(ctx context.Context, msg *pubsub.Message) {
	return func(ctx context.Context, msg *pubsub.Message) {
		var id uuid.UUID
		retryCount := 0

		for {
			id = uuid.New()
			_, loaded := m.LoadOrStore(id.String(), true)
			if !loaded {
				// IDがなければ処理を開始
				if debug {
					fmt.Printf("Processing with UUID: %s\n", id.String())
				}
				break
			}
			retryCount++
			if retryCount >= UUID_RETRY_MAX {
				fmt.Printf("UUID conflict after %d retries. Nack the message.\n", UUID_RETRY_MAX)
				msg.Nack()
				return
			}
		}

		// 実際の処理を呼び出し
		err := processFunc(ctx, msg, &id)
		if err != nil {
			fmt.Printf("Error processing and Nack the message UUID: %s: %v\n", id.String(), err)
			// fmt.Printf("Processing failed for UUID: %s. Nack the message.\n", id.String())
			m.Delete(id.String())
			msg.Nack()
			return
		}

		// 処理完了後、IDを削除
		m.Delete(id.String())
		if debug {
			fmt.Printf("Processing complete for UUID: %s. Ack the message.\n", id.String())
		}
		msg.Ack()
	}
}

func process(ctx context.Context, msg *pubsub.Message, id *uuid.UUID) error {
	// UUIDを文字列に変換
	uuidStr := id.String()

	// キュー1にメッセージを保存
	mu.Lock()
	receivedMessages[uuidStr] = msg

	// 結果通知チャネルを作成
	resultChan := make(chan int, 1)
	resultChans[uuidStr] = resultChan
	mu.Unlock()

	timeout := time.After(290 * time.Second)

	// 通知チャネルで待機
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timeout:
		return errors.New("timeout waiting for process result")
	case result := <-resultChan:
		if result == 0 {
			return nil
		} else {
			return fmt.Errorf("processing failed with result: %d", result)
		}
	}
}

// キュー4に結果を保存する例の関数
// 現在未使用
func saveProcessResult(id string, result int) {
	mu.Lock()
	defer mu.Unlock()

	processResults[id] = result
	if resultChan, exists := resultChans[id]; exists {
		resultChan <- result
		close(resultChan)
		delete(resultChans, id)
	}
}

func processBigQueryJob(ctx context.Context) int {
	// ctx, cancel := context.WithTimeout(ctx, 270*time.Second)
	// defer cancel()
	numReceivedMessages := 0
	waitCount := 0

	// 1. キュー2が空になるまで待つ
	for {
		mu.Lock()
		// Be careful, in some conditions, mu.Unlock() is deferred
		if len(preparingMessages) == 0 {
			numPrevReceivedMessages := numReceivedMessages
			numReceivedMessages = len(receivedMessages)
			fmt.Printf("Received %d -> %d messages\n", numPrevReceivedMessages, numReceivedMessages)
			if numReceivedMessages*2 > CONCURRENT_MESSAGES {
				// Many messages are waiting in the queue
				fmt.Printf("Too many messages are waiting in the queue\n")
				break
			} else if numPrevReceivedMessages != 0 && (numReceivedMessages-numPrevReceivedMessages) < RECEIVE_MESSAGES_THRESHOLD {
				fmt.Printf("Received messages %d is less than threshold %d\n", numReceivedMessages-numPrevReceivedMessages, RECEIVE_MESSAGES_THRESHOLD)
				break
			} else if numReceivedMessages > 0 {
				if waitCount > 5 {
					fmt.Printf("Waited for 5 seconds\n")
					break
				}
				waitCount++
			}
		}
		mu.Unlock()
		select {
		case <-ctx.Done():
			return 0
		case <-time.After(2 * time.Second):
		}
	}
	fmt.Printf("Start processing\n")

	// 2. キュー1からメッセージを取得し、削除する
	var batchMessages map[string]*pubsub.Message
	batchMessages = make(map[string]*pubsub.Message)
	i := 0
	for uuid, msg := range receivedMessages {
		if i >= CONCURRENT_MESSAGES {
			break
		}
		batchMessages[uuid] = msg
		delete(receivedMessages, uuid)
		i++
	}

	// 3. キュー2に保存
	for uuid, msg := range batchMessages {
		preparingMessages[uuid] = msg
	}
	// Deferred Unlock
	mu.Unlock() // 全ての操作が終わってからUnlock

	fmt.Printf("Processing %d messages\n", len(batchMessages))

	// 4. BigQueryのクエリ発行
	job, err := sendToBigQuery(ctx, batchMessages)

	// 5. キュー3にUUIDを保存し、キュー2から削除
	mu.Lock()
	for uuid := range batchMessages {
		delete(preparingMessages, uuid)
		sending[uuid] = struct{}{}
	}
	mu.Unlock()

	// 6. BigQueryのジョブ完了を待つ
	result := 0
	if err != nil {
		result = 1
		fmt.Printf("failed to run query: %v\n", err)
	} else {
		// BigQueryジョブの完了をチェック
		status, err := job.Wait(ctx)
		if err != nil {
			result = 1
			fmt.Printf("failed to wait for job: %v\n", err)
		} else if status.Err() != nil {
			result = 1
			fmt.Printf("query job failed: %v\n", status.Err())
		}
	}

	// 7. キュー3からUUIDを削除
	mu.Lock()
	for uuid := range batchMessages {
		delete(sending, uuid)
	}
	// 8. キュー4に結果を保存
	for uuid := range batchMessages {
		processResults[uuid] = result
	}
	mu.Unlock()

	// 最終処理
	mu.Lock()
	for uuid := range batchMessages {
		result := processResults[uuid]
		delete(processResults, uuid)
		if resultChan, exists := resultChans[uuid]; exists {
			resultChan <- result
			close(resultChan)
			delete(resultChans, uuid)
		}
	}
	mu.Unlock()

	return numReceivedMessages
}

func sendToBigQuery(ctx context.Context, messages map[string]*pubsub.Message) (*bigquery.Job, error) {
	var data []InstantData

	for _, msg := range messages {
		pointID := msg.Attributes["point_id"]
		power := msg.Attributes["power"]
		timestamp := msg.Attributes["timestamp"]

		// powerをint64に変換
		var instantPower int64
		fmt.Sscanf(power, "%d", &instantPower)

		// timestampをtime.Timeに変換
		var secondsFrom2k int64
		fmt.Sscanf(timestamp, "%d", &secondsFrom2k)
		// ts, err := time.Parse(time.RFC3339, timestamp)
		// if err != nil {
		// 	return nil, fmt.Errorf("failed to parse timestamp: %v", err)
		// }
		ts := time.Unix(secondsFrom2k+EPOCH_2K-JST_DIFF, 0).In(JST)

		data = append(data, InstantData{
			PointID:            pointID,
			Timestamp:          ts,
			InstantaneousPower: instantPower,
		})
	}

	return insertIntoBigQuery(ctx, data)
}

func insertIntoBigQuery(ctx context.Context, data []InstantData) (*bigquery.Job, error) {
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("failed to create bigquery client: %v", err)
	}
	defer client.Close()

	// BigQueryのクエリを作成
	query := "CALL`" + projectID + ".b_route.insert_instant_data`(@instant_data);"

	// クエリパラメータを設定
	queryParams := []bigquery.QueryParameter{
		{
			Name:  "instant_data",
			Value: data,
		},
	}

	// クエリの実行
	fmt.Printf("client.Query\n")
	q := client.Query(query)
	q.Parameters = queryParams

	return q.Run(ctx)
}

func pullMsgsSync(w io.Writer, projectID, subscriptionID string) error {
	// ctx := context.Background()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	last1Min := time.After(1 * time.Minute)

	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return fmt.Errorf("pubsub.NewClient: %w", err)
	}
	defer client.Close()

	totalProcessedMessages := 0

	// 起動時にprocessBigQueryJobのgoroutineを起動する
	go func() {
		bigQueryContext, bigQueryCancel := context.WithTimeout(ctx, 270*time.Second)
		defer bigQueryCancel()

		time.Sleep(10 * time.Second)
		processedMessages := 0
		isFinalTry := func() bool {
			select {
			case <-last1Min:
				fmt.Printf("Process end because the remaining time is less than 1 minute\n")
				return true
			default:
			}
			return processedMessages*2 < CONCURRENT_MESSAGES
		}
		for {
			fmt.Printf("Execute processBigQueryJob\n")
			processedMessages = processBigQueryJob(bigQueryContext)
			totalProcessedMessages += processedMessages
			if isFinalTry() {
				// Wait for Ack()
				time.Sleep(5 * time.Second)
				// if debug {
				fmt.Printf("Processed %d messages and quit\n", processedMessages)
				// }
				cancel()
				time.Sleep(5 * time.Second)
				break
			}
			select {
			case <-ctx.Done():
				return
			default:
				time.Sleep(10 * time.Second) // 定期的に呼び出す間隔を調整
			}
		}
	}()

	sub := client.Subscription(subscriptionID)
	m := sync.Map{}

	// Turn on synchronous mode. This makes the subscriber use the Pull RPC rather
	// than the StreamingPull RPC, which is useful for guaranteeing MaxOutstandingMessages,
	// the max number of messages the client will hold in memory at a time.
	sub.ReceiveSettings.Synchronous = true
	sub.ReceiveSettings.MaxOutstandingMessages = CONCURRENT_MESSAGES

	// Receive messages for 10 seconds, which simplifies testing.
	// Comment this out in production, since `Receive` should
	// be used as a long running operation.
	// ctx, cancel := context.WithTimeout(ctx, 120*time.Second)
	// ctx, cancel := context.WithCancel(ctx)
	// defer cancel()
	ctx, cancel = context.WithCancel(ctx)
	defer cancel()

	err = sub.Receive(ctx, NewMessageHandler(&m, process))
	fmt.Printf("sub.Receive end\n")
	if err != nil {
		return fmt.Errorf("sub.Receive: %w", err)
	}
	fmt.Fprintf(w, "Received %d messages\n", totalProcessedMessages)

	return nil
}
