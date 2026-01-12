# 既存リソースを Terraform 管理下に置くためのインポートブロック
# 利用する場合はコメントアウトを解除し、適宜 ID を実際の環境に合わせて調整する。

# /*
# --- BigQuery ---
import {
  to = module.bigquery.google_bigquery_dataset.dataset
  id = "projects/${var.project_id}/datasets/b_route"
}

import {
  to = module.bigquery.google_bigquery_table.instantaneous_usages
  id = "projects/${var.project_id}/datasets/b_route/tables/instantaneous_usages"
}

import {
  to = module.bigquery.google_bigquery_table.total_usages
  id = "projects/${var.project_id}/datasets/b_route/tables/total_usages"
}

import {
  to = module.bigquery.google_bigquery_routine.insert_instant_data
  id = "projects/${var.project_id}/datasets/b_route/routines/insert_instant_data"
}

import {
  to = module.bigquery.google_bigquery_routine.insert_total_data
  id = "projects/${var.project_id}/datasets/b_route/routines/insert_total_data"
}

import {
  to = module.bigquery.google_bigquery_table.instantaneous_usages_jst
  id = "projects/${var.project_id}/datasets/b_route/tables/instantaneous_usages_jst"
}

import {
  to = module.bigquery.google_bigquery_table.total_usages_jst
  id = "projects/${var.project_id}/datasets/b_route/tables/total_usages_jst"
}

# --- Pub/Sub ---
import {
  to = module.pubsub.google_pubsub_topic.instant
  id = "projects/${var.project_id}/topics/instant_electric_power"
}

import {
  to = module.pubsub.google_pubsub_topic.total
  id = "projects/${var.project_id}/topics/total_electric_power"
}

import {
  to = module.pubsub.google_pubsub_topic.instant_dead_letter
  id = "projects/${var.project_id}/topics/instant_subscription_dead-letter"
}

import {
  to = module.pubsub.google_pubsub_topic.total_dead_letter
  id = "projects/${var.project_id}/topics/total_subscription_dead-letter"
}

import {
  to = module.pubsub.google_pubsub_subscription.instant_pull
  id = "projects/${var.project_id}/subscriptions/instant_subscription"
}

import {
  to = module.pubsub.google_pubsub_subscription.instant_dead_letter_pull
  id = "projects/${var.project_id}/subscriptions/instant_subscription_dead-letter"
}

import {
  to = module.pubsub.google_pubsub_subscription.total_dead_letter_pull
  id = "projects/${var.project_id}/subscriptions/total_subscription_dead-letter"
}

import {
  to = module.scheduler.google_cloud_scheduler_job.job
  id = "projects/${var.project_id}/locations/${var.region}/jobs/instant2bq-trigger"
}

# --- Cloud Run functions ---
import {
  to = module.instant2bq.google_cloud_run_v2_service.default
  id = "projects/${var.project_id}/locations/asia-northeast1/services/instant2bq"
}

import {
  to = module.total2bq.google_cloud_run_v2_service.default
  id = "projects/${var.project_id}/locations/asia-northeast1/services/total2bq"
}

# --- Monitoring ---
import {
  to = module.monitoring.google_monitoring_alert_policy.pubsub_missing_data[0]
  id = "projects/${var.project_id}/alertPolicies/10024764851573760263"
}

import {
  to = module.monitoring.google_monitoring_notification_channel.email[0]
  id = "projects/${var.project_id}/notificationChannels/5199117289157940302"
}

# --- Cloud Run IAM ---
import {
  to = google_artifact_registry_repository.repo
  id = "projects/${var.project_id}/locations/${var.region}/repositories/cloud-run-source-deploy"
}

# --- Pub/Sub IAM ---
import {
  to = module.pubsub.google_pubsub_topic_iam_member.instant_dead_letter_publisher
  id = "projects/${var.project_id}/topics/instant_subscription_dead-letter roles/pubsub.publisher serviceAccount:service-500225389708@gcp-sa-pubsub.iam.gserviceaccount.com"
}

import {
  to = module.pubsub.google_pubsub_topic_iam_member.instant_publisher["allUsers"]
  id = "projects/${var.project_id}/topics/instant_electric_power roles/pubsub.publisher allUsers"
}

import {
  to = module.pubsub.google_pubsub_topic_iam_member.total_dead_letter_publisher
  id = "projects/${var.project_id}/topics/total_subscription_dead-letter roles/pubsub.publisher serviceAccount:service-500225389708@gcp-sa-pubsub.iam.gserviceaccount.com"
}

import {
  to = module.pubsub.google_pubsub_topic_iam_member.total_publisher["allUsers"]
  id = "projects/${var.project_id}/topics/total_electric_power roles/pubsub.publisher allUsers"
}

import {
  to = module.pubsub.google_pubsub_subscription_iam_member.instant_ack
  id = "projects/${var.project_id}/subscriptions/instant_subscription roles/pubsub.subscriber serviceAccount:service-500225389708@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# --- Services ---
import {
  to = resource.google_project_service.services[each.value]
  id = "${var.project_id}/${each.value}"
  for_each = [
    # "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "eventarc.googleapis.com",
    "storage.googleapis.com",
    "cloudapis.googleapis.com",
  ]
}

import {
  id = "projects/nk-home-data/locations/asia-northeast1/triggers/total2bq"
  to = module.total2bq.google_eventarc_trigger.default
}

# */
