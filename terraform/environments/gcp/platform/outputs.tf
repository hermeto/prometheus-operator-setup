output "cluster_name" {
  description = "GKE cluster name (input of the monitoring stack)."
  value       = module.gke.name
}

output "cluster_location" {
  description = "GKE cluster location (input of the monitoring stack)."
  value       = module.gke.location
}

output "network_name" {
  description = "VPC network name."
  value       = module.network.network_name
}

output "get_credentials_command" {
  description = "Writes a kubeconfig entry for the cluster."
  value       = module.gke.get_credentials_command
}
