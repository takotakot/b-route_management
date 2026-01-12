variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud Region for compute and regional resources (BigQuery is managed separately in US)"
  type        = string
  default     = "asia-northeast1"
}

variable "instant_topic_name" {
  description = "Name of the Pub/Sub topic for instantaneous usages"
  type        = string
  default     = "instant_electric_power"
}

variable "total_topic_name" {
  description = "Name of the Pub/Sub topic for total usages"
  type        = string
  default     = "total_electric_power"
}

variable "enable_monitoring" {
  description = "Whether to enable Cloud Monitoring alert policies"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  default     = null
}

variable "additional_notification_channels" {
  description = "List of existing notification channel IDs to attach to the alert policy"
  type        = list(string)
  default     = []
}

variable "activate_scheduler" {
  description = "Whether to enable (activate) the Cloud Scheduler job"
  type        = bool
  default     = true
}

variable "skip_build" {
  description = "Skip the build and push process for Cloud Run services"
  type        = bool
  default     = true
}
