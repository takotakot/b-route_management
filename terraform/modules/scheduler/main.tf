resource "google_cloud_scheduler_job" "job" {
  name             = var.job_name
  description      = "Trigger instant2bq function"
  schedule         = var.schedule
  time_zone        = "Asia/Tokyo"
  paused           = var.paused
  attempt_deadline = "180s"


  retry_config {
    retry_count          = 0
    max_retry_duration   = "0s"
    min_backoff_duration = "60s"
    max_backoff_duration = "3600s"
    max_doublings        = 5
  }

  http_target {
    http_method = "POST"
    uri         = var.target_url

    oidc_token {
      service_account_email = var.service_account_email
      audience              = var.target_url
    }
  }
}
