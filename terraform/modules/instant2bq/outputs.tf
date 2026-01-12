output "service_name" {
  value = google_cloud_run_v2_service.default.name
}

output "service_uri" {
  value = google_cloud_run_v2_service.default.uri
}

output "service_location" {
  value = google_cloud_run_v2_service.default.location
}
