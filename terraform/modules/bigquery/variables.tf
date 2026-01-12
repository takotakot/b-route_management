variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery Dataset ID"
  type        = string
  default     = "b_route"
}

variable "location" {
  description = "BigQuery Dataset Location"
  type        = string
  default     = "US"
}

variable "instantaneous_usages_table_id" {
  description = "Table ID for instantaneous usages"
  type        = string
  default     = "instantaneous_usages"
}

variable "total_usages_table_id" {
  description = "Table ID for total usages"
  type        = string
  default     = "total_usages"
}

variable "instantaneous_usages_partition_type" {
  description = "Partition type for instantaneous usages table"
  type        = string
  default     = "DAY"
}

variable "total_usages_partition_type" {
  description = "Partition type for total usages table"
  type        = string
  default     = "MONTH"
}

variable "instantaneous_usages_clustering" {
  description = "Clustering fields for instantaneous usages table"
  type        = list(string)
  default     = ["point_id", "timestamp"]
}

variable "instantaneous_usages_require_partition_filter" {
  description = "Whether to require partition filter for instantaneous usages table"
  type        = bool
  default     = true
}

variable "total_usages_require_partition_filter" {
  description = "Whether to require partition filter for total usages table"
  type        = bool
  default     = true
}

variable "total_usages_clustering" {
  description = "Clustering fields for total usages table"
  type        = list(string)
  default     = ["point_id", "timestamp"]
}

variable "instantaneous_usages_schema" {
  description = "JSON schema for instantaneous usages table"
  type        = string
}

variable "total_usages_schema" {
  description = "JSON schema for total usages table"
  type        = string
}

variable "instantaneous_usages_jst_schema" {
  description = "JSON schema for instantaneous usages JST view"
  type        = string
}

variable "total_usages_jst_schema" {
  description = "JSON schema for total usages JST view"
  type        = string
}

variable "instant_data_procedure_body" {
  description = "SQL body for insert_instant_data procedure"
  type        = string
}

variable "total_data_procedure_body" {
  description = "SQL body for insert_total_data procedure"
  type        = string
}

variable "instantaneous_usages_jst_query" {
  description = "SQL query for instantaneous_usages_jst view"
  type        = string
}

variable "total_usages_jst_query" {
  description = "SQL query for total_usages_jst view"
  type        = string
}

variable "instant_data_procedure_args_schema" {
  description = "JSON schema for insert_instant_data procedure arguments"
  type        = string
}

variable "total_data_procedure_args_schema" {
  description = "JSON schema for insert_total_data procedure arguments"
  type        = string
}
