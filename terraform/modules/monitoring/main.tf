resource "google_monitoring_notification_channel" "email" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Email Notification Channel"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_alert_policy" "pubsub_missing_data" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Pub/Sub data is missing"
  enabled      = var.alert_policy_enabled
  combiner     = "OR"

  conditions {
    display_name = "Cloud Pub/Sub Topic - Publish requests"
    condition_threshold {
      filter = "resource.type = \"pubsub_topic\" AND metric.type = \"pubsub.googleapis.com/topic/send_request_count\""
      # filter          = "resource.type = \"pubsub_topic\" AND metric.type = \"pubsub.googleapis.com/topic/send_request_count\" AND ${join(" OR ", [for t in var.topic_names : "resource.label.topic_id = \"${t}\""])}"
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 10
      trigger {
        percent = 90
      }
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
      evaluation_missing_data = "EVALUATION_MISSING_DATA_ACTIVE"
    }
  }

  notification_channels = concat(
    var.enable_monitoring ? [google_monitoring_notification_channel.email[0].name] : [],
    var.additional_notification_channels
  )

  documentation {
    content   = "Pub/Sub data is missing for topics: ${join(", ", var.topic_names)}"
    mime_type = "text/markdown"
    subject   = "Pub/Sub data is missing"
  }

  alert_strategy {
    notification_prompts = ["OPENED", "CLOSED"]
    notification_channel_strategy {
      notification_channel_names = concat(
        var.enable_monitoring ? [google_monitoring_notification_channel.email[0].name] : [],
        var.additional_notification_channels
      )
      renotify_interval = "3600s"
    }
  }
  lifecycle {
    ignore_changes = [
      # TODO: Remove
      documentation[0].content,
      documentation[0].mime_type,
    ]
  }

  severity = "WARNING"
}
