variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
}

variable "topic_names" {
  description = "List of Pub/Sub topic names to monitor for missing data"
  type        = list(string)
}

variable "enable_monitoring" {
  description = "Whether to create monitoring resources"
  type        = bool
  default     = true
}

variable "additional_notification_channels" {
  description = "List of existing notification channel IDs to attach to the alert policy"
  type        = list(string)
  default     = []
}

variable "alert_policy_enabled" {
  description = "Whether the monitoring alert policy is enabled"
  type        = bool
  default     = true
}
