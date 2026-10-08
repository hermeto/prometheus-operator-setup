variable "kubeconfig_path" {
  description = "kubeconfig that holds the kind cluster context."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context of the kind cluster (kind-<cluster name>)."
  type        = string
  default     = "kind-observability"
}

variable "cluster_name" {
  description = "Value of the `cluster` label on every series and alert."
  type        = string
  default     = "kind-observability"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. null generates one (see the grafana-admin Secret)."
  type        = string
  default     = null
  sensitive   = true
}

variable "alertmanager_slack_webhook_url" {
  description = "Optional Slack webhook to test notifications locally."
  type        = string
  default     = null
  sensitive   = true
}
