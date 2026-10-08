output "namespace" {
  description = "Namespace of the monitoring stack."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}

output "release_name" {
  description = "Helm release name of kube-prometheus-stack."
  value       = helm_release.stack.name
}

output "chart_version" {
  description = "Deployed kube-prometheus-stack chart version."
  value       = helm_release.stack.version
}

output "grafana_admin_secret" {
  description = "Secret holding the Grafana admin credentials (keys admin-user and admin-password)."
  value       = kubernetes_secret_v1.grafana_admin.metadata[0].name
}

output "grafana_admin_password" {
  description = "Grafana admin password."
  value       = local.grafana_admin_password
  sensitive   = true
}

output "alertmanager_config" {
  description = "Rendered Alertmanager configuration (holds no secrets; the Slack webhook is read from a file)."
  value       = yamlencode(local.alertmanager_config)
}

output "port_forward_commands" {
  description = "kubectl commands to reach the UIs locally."
  value = {
    grafana      = "kubectl -n ${var.namespace} port-forward svc/grafana 3000:80"
    prometheus   = "kubectl -n ${var.namespace} port-forward svc/kps-prometheus 9090:9090"
    alertmanager = "kubectl -n ${var.namespace} port-forward svc/kps-alertmanager 9093:9093"
  }
}

output "helm_values" {
  description = "Values documents passed to kube-prometheus-stack, in merge order (defaults, generated, extra)."
  value       = helm_release.stack.values
}

output "dashboard_config_maps" {
  description = "Names of the ConfigMaps holding the Grafana dashboards."
  value       = [for cm in kubernetes_config_map_v1.dashboards : cm.metadata[0].name]
}
