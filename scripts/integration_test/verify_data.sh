#!/bin/sh
# Verify data counts in BigQuery before and after testing.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config.sh"

# Get today's date in JST (YYYY-MM-DD)
TODAY_JST=$(date +%Y-%m-%d)

echo "=== Verifying data for $TODAY_JST (JST) ==="

echo ""
echo "--- instantaneous_usages_jst ---"
bq query --project_id="$PROJECT_ID" --use_legacy_sql=false \
  "SELECT COUNT(*) as row_count FROM \`$PROJECT_ID.b_route.instantaneous_usages_jst\` WHERE DATE(timestamp_jst) = '$TODAY_JST'"

echo ""
echo "--- total_usages_jst ---"
bq query --project_id="$PROJECT_ID" --use_legacy_sql=false \
  "SELECT COUNT(*) as row_count FROM \`$PROJECT_ID.b_route.total_usages_jst\` WHERE DATE(timestamp_jst) = '$TODAY_JST'"

echo ""
echo "--- Test point data (instant) ---"
bq query --project_id="$PROJECT_ID" --use_legacy_sql=false \
  "SELECT * FROM \`$PROJECT_ID.b_route.instantaneous_usages_jst\` WHERE point_id = '$TEST_POINT_ID' AND DATE(timestamp_jst) = '$TODAY_JST' ORDER BY timestamp_jst DESC LIMIT 5"

echo ""
echo "--- Test point data (total) ---"
bq query --project_id="$PROJECT_ID" --use_legacy_sql=false \
  "SELECT * FROM \`$PROJECT_ID.b_route.total_usages_jst\` WHERE point_id = '$TEST_POINT_ID' AND DATE(timestamp_jst) = '$TODAY_JST' ORDER BY timestamp_jst DESC LIMIT 5"


