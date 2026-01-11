#!/bin/sh
# Configuration for integration tests
# This file should NOT be committed with actual PROJECT_ID values.

# --- Required Configuration ---
# Set PROJECT_ID via environment variable or uncomment and set below.
# export PROJECT_ID="nk-home-data-dev"  # Example for dev

# Set Timezone for all scripts
export TZ="Asia/Tokyo"

if [ -z "$PROJECT_ID" ]; then
  echo "Error: PROJECT_ID environment variable is not set."
  echo "Usage: PROJECT_ID=<your-project-id> ./run_test.sh"
  exit 1
fi

# --- Derived Configuration ---
REGION="${REGION:-asia-northeast1}"
INSTANT_TOPIC="${INSTANT_TOPIC:-instant_electric_power}"
TOTAL_TOPIC="${TOTAL_TOPIC:-total_electric_power}"
INSTANT_SERVICE="${INSTANT_SERVICE:-instant2bq}"
SCHEDULER_JOB="${SCHEDULER_JOB:-instant2bq-trigger}"

# --- Test Data ---
TEST_POINT_ID="${TEST_POINT_ID:-integration-test-point}"

# Number of instant messages to publish for batch testing
INSTANT_MESSAGE_COUNT="${INSTANT_MESSAGE_COUNT:-10}"

echo "Configuration loaded:"
echo "  PROJECT_ID: $PROJECT_ID"
echo "  REGION: $REGION"
echo "  INSTANT_TOPIC: $INSTANT_TOPIC"
echo "  TOTAL_TOPIC: $TOTAL_TOPIC"
echo "  INSTANT_MESSAGE_COUNT: $INSTANT_MESSAGE_COUNT"

export REGION INSTANT_TOPIC TOTAL_TOPIC INSTANT_SERVICE SCHEDULER_JOB TEST_POINT_ID INSTANT_MESSAGE_COUNT
