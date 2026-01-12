resource "null_resource" "build_and_push" {
  count = var.skip_build ? 0 : 1
  triggers = {
    source_code_hash = var.source_code_hash
    build_command    = "gcloud builds submit ${path.module}/../../../${var.source_dir} --pack image=${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}/${var.image_name}:latest --env GOOGLE_FUNCTION_TARGET=total2bq --project ${var.project_id}"
  }

  provisioner "local-exec" {
    command = "gcloud builds submit ${path.module}/../../../${var.source_dir} --pack image=${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}/${var.image_name}:latest,env=GOOGLE_FUNCTION_TARGET=total2bq --project ${var.project_id}"
  }
}

resource "google_cloud_run_v2_service" "default" {
  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    annotations = var.source_code_hash != "" ? {
      "app.terraform.io/source-code-hash" = var.source_code_hash
    } : {}
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}/${var.image_name}:latest"

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory_mb
        }
        startup_cpu_boost = true
        cpu_idle          = true
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }

    timeout         = "${var.timeout_s}s"
    service_account = var.service_account_email
  }

  depends_on = [null_resource.build_and_push]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].containers[0].name,
      template[0].containers[0].base_image_uri,
      # Ignore unexpected build_config drift. Terraform shouldn't manage this unless we explicitly define it.
      build_config
    ]
  }
}

resource "google_eventarc_trigger" "default" {
  name     = var.trigger_name != "" ? var.trigger_name : "${var.service_name}-trigger"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.default.name
      region  = var.region
      path    = "/"
    }
  }

  transport {
    pubsub {
      topic = var.pubsub_topic
    }
  }

  service_account = var.trigger_service_account_email
}

data "google_project" "project" {}

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.trigger_service_account_email}"
}
