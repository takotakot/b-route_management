# Common Trigger Service Account (Scheduler/Eventarc)
resource "google_service_account" "trigger_sa" {
  account_id   = var.trigger_sa_name
  display_name = "B-Route Triggering Service Account"
}

# instant2bq Runtime Service Account
resource "google_service_account" "instant2bq_sa" {
  account_id   = var.instant2bq_sa_name
  display_name = "instant2bq Runtime Service Account"
}

# total2bq Runtime Service Account
resource "google_service_account" "total2bq_sa" {
  account_id   = var.total2bq_sa_name
  display_name = "total2bq Runtime Service Account"
}

# --- Permissions for instant2bq ---
resource "google_project_iam_member" "instant2bq_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.instant2bq_sa.email}"
}

resource "google_project_iam_member" "instant2bq_bq_job" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.instant2bq_sa.email}"
}

resource "google_project_iam_member" "instant2bq_bq_data" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.instant2bq_sa.email}"
}

# --- Permissions for total2bq ---
resource "google_project_iam_member" "total2bq_bq_job" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.total2bq_sa.email}"
}

resource "google_project_iam_member" "total2bq_bq_data" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.total2bq_sa.email}"
}

# --- Outputs ---
output "trigger_sa_email" {
  value = google_service_account.trigger_sa.email
}

output "instant2bq_sa_email" {
  value = google_service_account.instant2bq_sa.email
}

output "total2bq_sa_email" {
  value = google_service_account.total2bq_sa.email
}
