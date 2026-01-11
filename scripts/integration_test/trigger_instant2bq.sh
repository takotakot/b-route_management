#!/bin/sh
# Manually trigger the instant2bq Cloud Run service.
# Two methods are provided:
#   1. Via Cloud Scheduler (works even if job is paused)
#   2. Via direct curl (for cases where scheduler is unavailable)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/config.sh"

METHOD="${1:-scheduler}"

case "$METHOD" in
  scheduler)
    echo "=== Triggering instant2bq via Cloud Scheduler ==="
    echo "Note: This requires the scheduler job to be ENABLED (unpaused)."
    gcloud scheduler jobs run "$SCHEDULER_JOB" \
      --project="$PROJECT_ID" \
      --location="$REGION"
    ;;
  curl)
    echo "=== Triggering instant2bq via direct curl ==="
    SERVICE_URL=$(gcloud run services describe "$INSTANT_SERVICE" \
      --project="$PROJECT_ID" \
      --region="$REGION" \
      --format="value(status.url)")
    
    echo "Service URL: $SERVICE_URL"
    TOKEN=$(gcloud auth print-identity-token)
    
    curl -X POST "$SERVICE_URL/" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json"
    ;;
  *)
    echo "Usage: $0 [scheduler|curl]"
    echo "  scheduler: Trigger via Cloud Scheduler job (default)"
    echo "  curl: Trigger via direct HTTP request with auth"
    exit 1
    ;;
esac

echo ""
echo "Trigger sent. Check Cloud Run logs for processing status."
