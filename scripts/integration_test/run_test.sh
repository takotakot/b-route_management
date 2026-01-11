#!/bin/sh
# Main integration test runner.
# Usage: PROJECT_ID=<your-project-id> ./run_test.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config first to ensure variables are available
. "$SCRIPT_DIR/config.sh"

echo "=============================================="
echo "  B-Route Integration Test Runner"
echo "=============================================="
echo ""

echo ""
printf "Press Enter to start the integration test (this will first verify current data)..."
read dummy
echo ""

# Step 1: Pre-test verification
echo ">>> Step 1: Pre-test data verification"
"$SCRIPT_DIR/verify_data.sh"
echo ""

# Step 2: Publish messages
echo ""
echo ">>> Step 2: Publishing test messages"
"$SCRIPT_DIR/publish_instant.sh"
echo ""
"$SCRIPT_DIR/publish_total.sh"
echo ""

# Step 3: Wait for Eventarc to process total2bq
echo ">>> Step 3: Waiting 30 seconds for Eventarc to trigger total2bq..."
sleep 30

# Step 4: Trigger instant2bq
echo ""
echo ">>> Step 4: Triggering instant2bq"
"$SCRIPT_DIR/trigger_instant2bq.sh" "${TRIGGER_METHOD:-scheduler}"
echo ""

# Step 5: Wait for processing
echo ">>> Step 5: Waiting 60 seconds for processing to complete..."
sleep 60

# Step 6: Post-test verification
echo ""
echo ">>> Step 6: Post-test data verification"
"$SCRIPT_DIR/verify_data.sh"

echo ""
echo "=============================================="
echo "  Integration Test Complete"
echo "=============================================="
echo ""
echo "Please verify that:"
echo "  - Row counts increased by $INSTANT_MESSAGE_COUNT for instant (test point)"
echo "  - Row counts increased by 1 for total (test point)"
echo "  - New rows have point_id = '$TEST_POINT_ID'"
echo "  - Timestamps are correct (today in JST, spread over ~$((INSTANT_MESSAGE_COUNT * MESSAGE_INTERVAL))s)"
