output "namespace" {
  description = "Namespace of the monitoring stack."
  value       = module.monitoring.namespace
}

output "chart_version" {
  description = "Deployed kube-prometheus-stack chart version."
  value       = module.monitoring.chart_version
}

output "grafana_admin_secret" {
  description = "Secret with the Grafana admin credentials."
  value       = module.monitoring.grafana_admin_secret
}

output "port_forward_commands" {
  description = "kubectl commands to reach the UIs."
  value       = module.monitoring.port_forward_commands
}

output "helm_values" {
  description = "Values passed to kube-prometheus-stack, in merge order (no secrets; verified by tests)."
  value       = module.monitoring.helm_values
}
