output "name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "location" {
  description = "Cluster location (region or zone)."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "Control plane endpoint."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded public CA certificate of the cluster."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool of the cluster."
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_service_account" {
  description = "Email of the node service account."
  value       = google_service_account.nodes.email
}

output "get_credentials_command" {
  description = "Command that writes a kubeconfig entry for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --location ${google_container_cluster.this.location} --project ${var.project_id}"
}
