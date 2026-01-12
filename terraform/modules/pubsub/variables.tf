variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
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

variable "instant_dead_letter_topic_name" {
  description = "Name of the dead letter topic for instantaneous usages"
  type        = string
  default     = "instant_subscription_dead-letter"
}

variable "total_dead_letter_topic_name" {
  description = "Name of the dead letter topic for total usages"
  type        = string
  default     = "total_subscription_dead-letter"
}

variable "instant_subscription_name" {
  description = "Name of the pull subscription for instantaneous usages"
  type        = string
  default     = "instant-usage-sub"
}

variable "total_subscription_name" {
  description = "Name of the push subscription for total usages"
  type        = string
  default     = "total-usage-push-sub"
}

variable "instant_dead_letter_subscription_name" {
  description = "Name of the dead letter subscription for instantaneous usages"
  type        = string
  default     = ""
}

variable "total_dead_letter_subscription_name" {
  description = "Name of the dead letter subscription for total usages"
  type        = string
  default     = ""
}

variable "push_endpoint" {
  description = "HTTP endpoint for the push subscription"
  type        = string
  default     = ""
}

variable "push_service_account_email" {
  description = "Service account email for OIDC token in push subscription"
  type        = string
  default     = ""
}

variable "publishers" {
  description = "List of entities allowed to publish to the topics (e.g., ['allUsers', 'serviceAccount:foo@bar.com'])"
  type        = list(string)
  default     = []
}

variable "create_total_push_subscription" {
  description = "Whether to create the total push subscription manually. Set to false if using Eventarc triggers."
  type        = bool
  default     = true
}

variable "instant_ack_deadline_seconds" {
  description = "ACK deadline in seconds for instant subscription"
  type        = number
  default     = 270
}

variable "total_ack_deadline_seconds" {
  description = "ACK deadline in seconds for total subscription"
  type        = number
  default     = 600
}

variable "dead_letter_ack_deadline_seconds" {
  description = "ACK deadline in seconds for dead letter subscriptions"
  type        = number
  default     = 600
}

variable "subscription_max_delivery_attempts" {
  description = "Max delivery attempts for dead letter policy"
  type        = number
  default     = 5
}

variable "enable_subscription_retry_policy" {
  description = "Whether to enable retry policy for subscriptions"
  type        = bool
  default     = false
}

variable "subscription_retry_minimum_backoff" {
  description = "Minimum backoff for retry policy"
  type        = string
  default     = "10s"
}

variable "subscription_retry_maximum_backoff" {
  description = "Maximum backoff for retry policy"
  type        = string
  default     = "600s"
}
