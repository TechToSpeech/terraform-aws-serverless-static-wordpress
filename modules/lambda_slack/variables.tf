variable "site_name" {
  type        = string
  description = "Unique internal name for the site."
}
variable "slack_webhook" {
  type        = string
  description = "The Slack webhook URL where ECS Cluster EventBridge notifications will be sent."
}
variable "ecs_cluster_arn" {
  type        = string
  description = "The ARN of the ECS cluster where events are being monitored."
}
