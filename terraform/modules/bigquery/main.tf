resource "google_bigquery_dataset" "dataset" {
  dataset_id                 = var.dataset_id
  location                   = var.location
  description                = "B-Route management dataset"
  delete_contents_on_destroy = false
}

resource "google_bigquery_table" "instantaneous_usages" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = var.instantaneous_usages_table_id
  schema     = var.instantaneous_usages_schema
  clustering = var.instantaneous_usages_clustering

  time_partitioning {
    type  = var.instantaneous_usages_partition_type
    field = "timestamp"
  }

  require_partition_filter = var.instantaneous_usages_require_partition_filter
}

resource "google_bigquery_table" "total_usages" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = var.total_usages_table_id
  schema     = var.total_usages_schema
  clustering = var.total_usages_clustering

  time_partitioning {
    type  = var.total_usages_partition_type
    field = "timestamp"
  }

  require_partition_filter = var.total_usages_require_partition_filter
}

# Views
resource "google_bigquery_table" "instantaneous_usages_jst" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "${var.instantaneous_usages_table_id}_jst"
  schema     = var.instantaneous_usages_jst_schema
  view {
    query          = var.instantaneous_usages_jst_query
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.instantaneous_usages]
}

resource "google_bigquery_table" "total_usages_jst" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "${var.total_usages_table_id}_jst"
  schema     = var.total_usages_jst_schema
  view {
    query          = var.total_usages_jst_query
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.total_usages]
}

# Stored Procedures
resource "google_bigquery_routine" "insert_instant_data" {
  dataset_id      = google_bigquery_dataset.dataset.dataset_id
  routine_id      = "insert_instant_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = var.instant_data_procedure_body

  arguments {
    name      = "insert_values"
    data_type = var.instant_data_procedure_args_schema
  }

  lifecycle {
    ignore_changes = [arguments[0].argument_kind]
  }
}

resource "google_bigquery_routine" "insert_total_data" {
  dataset_id      = google_bigquery_dataset.dataset.dataset_id
  routine_id      = "insert_total_data"
  routine_type    = "PROCEDURE"
  language        = "SQL"
  definition_body = var.total_data_procedure_body

  arguments {
    name      = "insert_values"
    data_type = var.total_data_procedure_args_schema
  }

  lifecycle {
    ignore_changes = [arguments[0].argument_kind]
  }
}
