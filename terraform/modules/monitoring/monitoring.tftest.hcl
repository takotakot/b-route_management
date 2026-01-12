provider "google" {
  project = "test-project"
}

variables {
  project_id         = "test-project"
  notification_email = "test@example.com"
  topic_names        = ["test-topic"]
}

run "validate_monitoring_enabled" {
  command = plan

  variables {
    enable_monitoring = true
  }

  assert {
    condition     = length(google_monitoring_alert_policy.pubsub_missing_data) == 1
    error_message = "Monitoring alert policy should be created when enable_monitoring is true"
  }
}

run "validate_monitoring_disabled" {
  command = plan

  variables {
    enable_monitoring = false
  }

  assert {
    condition     = length(google_monitoring_alert_policy.pubsub_missing_data) == 0
    error_message = "Monitoring alert policy should not be created when enable_monitoring is false"
  }
}
