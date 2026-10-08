variable "project_id" {
  description = "GCP project of the cluster."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name (output cluster_name of the platform stack)."
  type        = string
  default     = "observability"
}

variable "cluster_location" {
  description = "GKE cluster location (output cluster_location of the platform stack)."
  type        = string
  default     = "us-central1"
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "15d"
}

variable "prometheus_retention_size" {
  description = "Maximum TSDB size; keep it below prometheus_storage_size."
  type        = string
  default     = "40GB"
}

variable "prometheus_storage_size" {
  description = "Size of the Prometheus volume."
  type        = string
  default     = "50Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. null generates one (see the grafana-admin Secret)."
  type        = string
  default     = null
  sensitive   = true
}

variable "alertmanager_slack_webhook_url" {
  description = "Slack incoming webhook. Provide it with TF_VAR_alertmanager_slack_webhook_url, never in a committed file."
  type        = string
  default     = null
  sensitive   = true
}

variable "alertmanager_slack_channel" {
  description = "Slack channel for notifications."
  type        = string
  default     = "#alerts"
}
