resource "google_pubsub_topic" "instant" {
  name = var.instant_topic_name
}

resource "google_pubsub_topic" "total" {
  name = var.total_topic_name
}

# Dead Letter Topics
resource "google_pubsub_topic" "instant_dead_letter" {
  name = var.instant_dead_letter_topic_name
}

resource "google_pubsub_topic" "total_dead_letter" {
  name = var.total_dead_letter_topic_name
}

resource "google_pubsub_subscription" "instant_pull" {
  name  = var.instant_subscription_name
  topic = google_pubsub_topic.instant.name

  ack_deadline_seconds = var.instant_ack_deadline_seconds

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.instant_dead_letter.id
    max_delivery_attempts = var.subscription_max_delivery_attempts
  }

  dynamic "retry_policy" {
    for_each = var.enable_subscription_retry_policy ? [1] : []
    content {
      minimum_backoff = var.subscription_retry_minimum_backoff
      maximum_backoff = var.subscription_retry_maximum_backoff
    }
  }
}

resource "google_pubsub_subscription" "total_push" {
  count = var.create_total_push_subscription ? 1 : 0
  name  = var.total_subscription_name
  topic = google_pubsub_topic.total.name

  push_config {
    push_endpoint = var.push_endpoint
    oidc_token {
      service_account_email = var.push_service_account_email
    }
  }

  ack_deadline_seconds = var.total_ack_deadline_seconds

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.total_dead_letter.id
    max_delivery_attempts = var.subscription_max_delivery_attempts
  }

  dynamic "retry_policy" {
    for_each = var.enable_subscription_retry_policy ? [1] : []
    content {
      minimum_backoff = var.subscription_retry_minimum_backoff
      maximum_backoff = var.subscription_retry_maximum_backoff
    }
  }
}

# Subscriptions for Dead Letter Topics (Pull type)
resource "google_pubsub_subscription" "instant_dead_letter_pull" {
  name  = var.instant_dead_letter_subscription_name != "" ? var.instant_dead_letter_subscription_name : "${var.instant_subscription_name}_dead-letter"
  topic = google_pubsub_topic.instant_dead_letter.name

  ack_deadline_seconds = var.dead_letter_ack_deadline_seconds

  dynamic "retry_policy" {
    for_each = var.enable_subscription_retry_policy ? [1] : []
    content {
      minimum_backoff = var.subscription_retry_minimum_backoff
      maximum_backoff = var.subscription_retry_maximum_backoff
    }
  }
}

resource "google_pubsub_subscription" "total_dead_letter_pull" {
  name  = var.total_dead_letter_subscription_name != "" ? var.total_dead_letter_subscription_name : "${var.total_subscription_name}_dead-letter"
  topic = google_pubsub_topic.total_dead_letter.name

  ack_deadline_seconds = var.dead_letter_ack_deadline_seconds

  dynamic "retry_policy" {
    for_each = var.enable_subscription_retry_policy ? [1] : []
    content {
      minimum_backoff = var.subscription_retry_minimum_backoff
      maximum_backoff = var.subscription_retry_maximum_backoff
    }
  }
}

# IAM for Dead Letter Policy
# Pub/Sub service account needs to be able to Publish to dead letter topics
# and acknowledge messages on the main subscriptions.
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_pubsub_topic_iam_member" "instant_dead_letter_publisher" {
  topic  = google_pubsub_topic.instant_dead_letter.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "total_dead_letter_publisher" {
  topic  = google_pubsub_topic.total_dead_letter.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "instant_ack" {
  subscription = google_pubsub_subscription.instant_pull.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "total_ack" {
  count        = var.create_total_push_subscription ? 1 : 0
  subscription = google_pubsub_subscription.total_push[0].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "instant_publisher" {
  for_each = toset(var.publishers)
  topic    = google_pubsub_topic.instant.name
  role     = "roles/pubsub.publisher"
  member   = each.value
}

resource "google_pubsub_topic_iam_member" "total_publisher" {
  for_each = toset(var.publishers)
  topic    = google_pubsub_topic.total.name
  role     = "roles/pubsub.publisher"
  member   = each.value
}

output "instant_subscription_id" {
  value = google_pubsub_subscription.instant_pull.id
}
