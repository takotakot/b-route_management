terraform {
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.14"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
}

locals {
  services = [
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

resource "google_project_service" "services" {
  for_each = toset(local.services)
  project  = var.project_id
  service  = each.value

  disable_on_destroy = false
}

module "bigquery" {
  source     = "../../modules/bigquery"
  project_id = var.project_id

  instantaneous_usages_clustering = ["point_id", "timestamp"]
  instantaneous_usages_schema     = jsonencode(yamldecode(file("${path.module}/../../../bigquery/instantaneous_usages.yaml")))

  total_usages_clustering = ["point_id", "timestamp"]
  total_usages_schema     = jsonencode(yamldecode(file("${path.module}/../../../bigquery/total_usages.yaml")))


  instantaneous_usages_jst_schema = jsonencode(yamldecode(file("${path.module}/../../../bigquery/instantaneous_usages_jst.yaml")))
  total_usages_jst_schema         = jsonencode(yamldecode(file("${path.module}/../../../bigquery/total_usages_jst.yaml")))

  instant_data_procedure_args_schema = jsonencode(yamldecode(file("${path.module}/../../../bigquery/insert_instant_data_args.yaml")))
  total_data_procedure_args_schema   = jsonencode(yamldecode(file("${path.module}/../../../bigquery/insert_total_data_args.yaml")))

  instant_data_procedure_body = templatefile("${path.module}/../../../bigquery/insert_instant_data.sql", {
    dataset_id = "b_route"
    table_id   = "instantaneous_usages"
  })

  total_data_procedure_body = templatefile("${path.module}/../../../bigquery/insert_total_data.sql", {
    dataset_id = "b_route"
    table_id   = "total_usages"
  })

  instantaneous_usages_jst_query = templatefile("${path.module}/../../../bigquery/instantaneous_usages_jst.sql", {
    dataset_id = "b_route"
    table_id   = "instantaneous_usages"
  })
  total_usages_jst_query = templatefile("${path.module}/../../../bigquery/total_usages_jst.sql", {
    dataset_id = "b_route"
    table_id   = "total_usages"
  })
}

module "pubsub" {
  source                         = "../../modules/pubsub"
  project_id                     = var.project_id
  instant_topic_name             = var.instant_topic_name
  total_topic_name               = var.total_topic_name
  instant_subscription_name      = "instant_subscription"
  total_subscription_name        = "total_subscription"
  create_total_push_subscription = false

  publishers = [] # Restricted in dev as per user request
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "cloud-run-source-deploy"
  description   = "Cloud Run Source Deployments"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

module "instant2bq" {
  source = "../../modules/instant2bq"

  project_id    = var.project_id
  region        = var.region
  repository_id = google_artifact_registry_repository.repo.repository_id

  service_name = "instant2bq"
  image_name   = "instant2bq"
  source_dir   = "instant2bq"

  subscription_id               = "instant_subscription"
  service_account_email         = module.iam.instant2bq_sa_email
  trigger_service_account_email = module.iam.trigger_sa_email

  source_code_hash = var.skip_build ? "" : sha256(join("", [for f in fileset("${path.module}/../../../instant2bq", "**") : filesha256("${path.module}/../../../instant2bq/${f}")]))

  timeout_s           = 300
  memory_mb           = "128Mi"
  cpu                 = "167m"
  deletion_protection = false
  skip_build          = var.skip_build
}

module "total2bq" {
  source = "../../modules/total2bq"

  project_id    = var.project_id
  region        = var.region
  repository_id = google_artifact_registry_repository.repo.repository_id

  service_name = "total2bq"
  image_name   = "total2bq"
  source_dir   = "total2bq"

  pubsub_topic                  = "projects/${var.project_id}/topics/${var.total_topic_name}"
  trigger_name                  = "total2bq"
  trigger_service_account_email = module.iam.trigger_sa_email
  service_account_email         = module.iam.total2bq_sa_email

  source_code_hash = var.skip_build ? "" : sha256(join("", [for f in fileset("${path.module}/../../../total2bq", "**") : filesha256("${path.module}/../../../total2bq/${f}")]))

  timeout_s           = 300
  memory_mb           = "128Mi"
  cpu                 = "80m"
  deletion_protection = false
  skip_build          = var.skip_build
}

module "monitoring" {
  source     = "../../modules/monitoring"
  project_id = var.project_id

  # Set false after the integration test ends
  enable_monitoring                = var.enable_monitoring
  notification_email               = var.notification_email
  additional_notification_channels = var.additional_notification_channels
  topic_names                      = [var.instant_topic_name, var.total_topic_name]
}

module "scheduler" {
  source                = "../../modules/scheduler"
  project_id            = var.project_id
  region                = var.region
  target_url            = module.instant2bq.service_uri
  service_account_email = module.iam.trigger_sa_email
  paused                = !var.activate_scheduler
}
