package total2bq

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"cloud.google.com/go/bigquery"
	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

const EPOCH_2K = 946684800
const JST_DIFF = 9 * 60 * 60

var (
	JST = time.FixedZone("Asia/Tokyo", JST_DIFF)
)

type TotalData struct {
	PointID    string
	Timestamp  time.Time
	TotalPower string
}

// PubSubMessage is the payload of a Pub/Sub event.
type PubSubMessage struct {
	Attributes  map[string]string `json:"attributes"`
	Data        []byte            `json:"data,omitempty"`
	ID          string            `json:"messageId"`
	PublishTime string            `json:"publishTime"`
}

type PushRequest struct {
	Message      PubSubMessage `json:"message"`
	Subscription string        `json:"subscription"`
}

func init() {
	functions.HTTP("total2bq", total2bq)
}

func total2bq(w http.ResponseWriter, r *http.Request) {
	projectID := os.Getenv("PROJECT_ID")
	if projectID == "" {
		http.Error(w, "Missing PROJECT_ID environment variable", http.StatusInternalServerError)
		return
	}

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Could not decode body: %v", err), http.StatusBadRequest)
		return
	}

	if len(req.Message.Attributes) == 0 {
		http.Error(w, "Missing attributes", http.StatusBadRequest)
		return
	}

	pointID := req.Message.Attributes["point_id"]
	power := req.Message.Attributes["power"]
	timestampStr := req.Message.Attributes["timestamp_str"]
	fmt.Printf("timestamp: %s, power: %s\n", timestampStr, power)

	// Use power as string directly
	totalPower := power

	// Convert timestamp to time.Time
	ts, err := time.ParseInLocation("2006-01-02 15:04:05", timestampStr, JST)
	if err != nil {
		http.Error(w, fmt.Sprintf("Invalid timestamp format: %v", err), http.StatusBadRequest)
		return
	}

	data := []TotalData{
		{
			PointID:    pointID,
			Timestamp:  ts,
			TotalPower: totalPower,
		},
	}

	ctx := r.Context()
	job, err := insertIntoBigQuery(ctx, projectID, data)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to insert into BigQuery: %v", err), http.StatusInternalServerError)
		return
	}

	status, err := job.Wait(ctx)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to wait for job: %v", err), http.StatusInternalServerError)
		return
	}
	if status.Err() != nil {
		http.Error(w, fmt.Sprintf("Query job failed: %v", status.Err()), http.StatusInternalServerError)
		return
	}

	fmt.Fprintln(w, "Message processed successfully")
}

func insertIntoBigQuery(ctx context.Context, projectID string, data []TotalData) (*bigquery.Job, error) {
	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("failed to create bigquery client: %v", err)
	}
	defer client.Close()

	// Create a BigQuery query statement
	query := "CALL`" + projectID + ".b_route.insert_total_data`(@total_data);"

	// Set query parameters
	queryParams := []bigquery.QueryParameter{
		{
			Name:  "total_data",
			Value: data,
		},
	}

	// Send the query to BigQuery
	q := client.Query(query)
	q.Parameters = queryParams

	return q.Run(ctx)
}
