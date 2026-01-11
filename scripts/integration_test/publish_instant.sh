#!/bin/sh
# instant_electric_power トピックへ複数のテストメッセージを publish する。
# instant2bq はバッチ処理を行うため、複数メッセージが必要。
#
# === テスト設計について ===
# この結合テストは「基本パターン」のみを採用。
# 理由:
#   - 結合テストの目的は Pub/Sub → Cloud Run → BigQuery のパイプラインが
#     正常に動作することの確認であり、データの正確性検証ではない。
#   - 同一時刻のメッセージ処理や時刻逆転のエッジケースは、
#     SQL の insert_instant_data プロシージャの責務であり、
#     SQL 単体テストでカバーすべき。
#   - 結合テストに複雑性を加えると保守コストが増加する一方、
#     得られるのは SQL で既に保証されている動作の再確認のみ。
#
# 補足:
#   - 将来的に、最初の2メッセージを同一時刻にする等、データに複雑性を
#     持たせる工夫で予期しないバグを発見できる可能性はある。
#   - ただし現時点では、シンプルさを優先し基本パターンを採用。
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config.sh"

# タイムスタンプ計算用定数
# EPOCH_2K = 946684800 (2000-01-01 00:00:00 UTC の Unix エポック)
# JST_DIFF = 9 * 3600 = 32400
EPOCH_2K=946684800
JST_DIFF=32400

# メッセージ間の待機時間（秒）
MESSAGE_INTERVAL="${MESSAGE_INTERVAL:-2}"

echo "=== instant_electric_power トピックへ $INSTANT_MESSAGE_COUNT 件のメッセージを publish ==="
echo "    (${MESSAGE_INTERVAL}秒間隔で順次送信)"

i=0
while [ $i -lt "$INSTANT_MESSAGE_COUNT" ]; do
  # publish 時点のリアルタイムでタイムスタンプを計算
  CURRENT_UNIX=$(date +%s)
  TIMESTAMP=$((CURRENT_UNIX - EPOCH_2K + JST_DIFF))

  # 100〜2000W の範囲でランダムな電力値を生成
  # /dev/urandom を使用（POSIX sh 互換）
  POWER=$(($(od -An -tu2 -N2 /dev/urandom | tr -d ' ') % 1901 + 100))

  echo "  [$((i + 1))/$INSTANT_MESSAGE_COUNT] point_id=$TEST_POINT_ID, power=${POWER}W, timestamp=$TIMESTAMP"

  gcloud pubsub topics publish "$INSTANT_TOPIC" \
    --project="$PROJECT_ID" \
    --attribute="point_id=$TEST_POINT_ID,power=$POWER,timestamp=$TIMESTAMP"

  i=$((i + 1))
  
  # 最後のメッセージ以外は待機
  if [ $i -lt "$INSTANT_MESSAGE_COUNT" ]; then
    sleep "$MESSAGE_INTERVAL"
  fi
done

echo "$INSTANT_MESSAGE_COUNT 件のメッセージを正常に publish しました。"
