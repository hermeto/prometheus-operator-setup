variable "cluster_name" {
  description = "Name of the cluster, added as the `cluster` external label to every series and alert."
  type        = string
}

variable "namespace" {
  description = "Namespace of the monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Helm release name of kube-prometheus-stack."
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_repository" {
  description = "Helm repository of the prometheus-community charts."
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "chart_version" {
  description = "Version of the kube-prometheus-stack chart."
  type        = string
  default     = "92.0.0"
}

variable "crds_chart_version" {
  description = "Version of the prometheus-operator-crds chart. Must ship the CRDs of the operator bundled with chart_version."
  type        = string
  default     = "32.0.1"
}

variable "helm_timeout" {
  description = "Seconds Helm waits for the release to become ready."
  type        = number
  default     = 900
}

variable "values" {
  description = "Extra values documents (YAML strings) merged after the module defaults, in order."
  type        = list(string)
  default     = []
}

variable "persistence_enabled" {
  description = "Store Prometheus and Alertmanager data on PersistentVolumes. Disable only for throwaway clusters."
  type        = bool
  default     = true
}

variable "storage_class_name" {
  description = "StorageClass for the PersistentVolumes. null uses the cluster default."
  type        = string
  default     = null
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "15d"

  validation {
    condition     = can(regex("^[0-9]+(ms|s|m|h|d|w|y)$", var.prometheus_retention))
    error_message = "prometheus_retention must be a Prometheus duration, e.g. 15d."
  }
}

variable "prometheus_retention_size" {
  description = "Maximum size of the TSDB before old blocks are deleted (e.g. 40GB). Keep it below the volume size."
  type        = string
  default     = "40GB"
}

variable "prometheus_storage_size" {
  description = "Size of the Prometheus volume."
  type        = string
  default     = "50Gi"
}

variable "alertmanager_storage_size" {
  description = "Size of the Alertmanager volume."
  type        = string
  default     = "5Gi"
}

variable "scrape_control_plane" {
  description = "Scrape kube-controller-manager, kube-scheduler, etcd and kube-proxy. Keep false on managed control planes (GKE), where they are not reachable."
  type        = bool
  default     = false
}

variable "grafana_admin_user" {
  description = "Grafana administrator login."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password. null generates a random one, readable from the grafana-admin Secret."
  type        = string
  default     = null
  sensitive   = true
}

variable "alertmanager_slack_webhook_url" {
  description = "Slack incoming webhook for notifications. null keeps alerts inside Alertmanager only. Stored in a Secret, never in Helm values."
  type        = string
  default     = null
  sensitive   = true
}

variable "alertmanager_slack_channel" {
  description = "Slack channel that receives the notifications."
  type        = string
  default     = "#alerts"
}

variable "prometheus_rules" {
  description = "Extra Prometheus rule files, as a map of name => YAML content in the standard `groups:` format."
  type        = map(string)
  default     = {}
}

variable "grafana_dashboards" {
  description = "Extra Grafana dashboards, as a map of file name => dashboard JSON. Loaded by the Grafana sidecar."
  type        = map(string)
  default     = {}
}
