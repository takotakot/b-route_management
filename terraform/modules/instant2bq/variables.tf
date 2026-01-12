variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry Repository ID"
}

variable "service_name" {
  type    = string
  default = "instant2bq"
}

variable "image_name" {
  type    = string
  default = "instant2bq"
}

variable "source_dir" {
  type        = string
  description = "Relative path to source directory from root"
}

variable "subscription_id" {
  type        = string
  description = "Pub/Sub Subscription ID to pull from"
}

variable "service_account_email" {
  type        = string
  description = "Service Account Email to run the function (Runtime Identity)"
}

variable "trigger_service_account_email" {
  type        = string
  description = "Service Account Email that triggers this function (Trigger Identity)"
}

variable "timeout_s" {
  type    = number
  default = 300
}

variable "memory_mb" {
  type    = string
  default = "128Mi"
}

variable "cpu" {
  type    = string
  default = "167m"
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "source_code_hash" {
  description = "Hash of the source code to trigger rebuilds"
  type        = string
  default     = ""
}

variable "skip_build" {

  type        = bool
  description = "Skip the build and push process"
  default     = false
}

variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection for Cloud Run service"
  default     = true
}
