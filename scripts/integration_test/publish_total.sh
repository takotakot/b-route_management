#!/bin/sh
# Publish a test message to the total_electric_power topic.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config.sh"

# Get current timestamp in JST format (YYYY-MM-DD HH:MM:SS)
TIMESTAMP_STR=$(date "+%Y-%m-%d %H:%M:%S")

# Random power value (kWh) like "123.45" using /dev/urandom for POSIX sh
POWER_INT=$(($(od -An -tu2 -N2 /dev/urandom | tr -d ' ') % 500 + 100))
POWER_DEC=$(($(od -An -tu2 -N2 /dev/urandom | tr -d ' ') % 100))
POWER=$(printf "%d.%02d" $POWER_INT $POWER_DEC)

echo "=== Publishing to total_electric_power topic ==="
echo "  point_id: $TEST_POINT_ID"
echo "  power: $POWER kWh"
echo "  timestamp_str: $TIMESTAMP_STR"

gcloud pubsub topics publish "$TOTAL_TOPIC" \
  --project="$PROJECT_ID" \
  --attribute="point_id=$TEST_POINT_ID,power=$POWER,timestamp_str=$TIMESTAMP_STR"

echo "Message published successfully."
