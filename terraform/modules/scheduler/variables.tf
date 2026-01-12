variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Region for scheduler"
  type        = string
  default     = "asia-northeast1"
}

variable "job_name" {
  description = "Name of the scheduler job"
  type        = string
  default     = "instant2bq-trigger"
}

variable "schedule" {
  description = "Cron schedule"
  type        = string
  default     = "*/5 * * * *"
}

variable "target_url" {
  description = "URL to trigger"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for OIDC token"
  type        = string
}

variable "paused" {
  description = "Whether the job is paused"
  type        = bool
  default     = false
}
