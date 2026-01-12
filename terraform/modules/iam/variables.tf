variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "trigger_sa_name" {
  description = "Name of the common trigger service account"
  type        = string
  default     = "broute-trigger-sa"
}

variable "instant2bq_sa_name" {
  description = "Name of the instant2bq runtime service account"
  type        = string
  default     = "instant2bq-sa"
}

variable "total2bq_sa_name" {
  description = "Name of the total2bq runtime service account"
  type        = string
  default     = "total2bq-sa"
}
