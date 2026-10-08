output "network_id" {
  description = "ID of the VPC network."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Name of the VPC network."
  value       = google_compute_network.this.name
}

output "subnetwork_id" {
  description = "ID of the subnetwork used by the GKE nodes."
  value       = google_compute_subnetwork.this.id
}

output "subnetwork_name" {
  description = "Name of the subnetwork used by the GKE nodes."
  value       = google_compute_subnetwork.this.name
}

output "pods_range_name" {
  description = "Name of the secondary range for Pods."
  value       = local.pods_range_name
}

output "services_range_name" {
  description = "Name of the secondary range for Services."
  value       = local.services_range_name
}

output "node_network_tag" {
  description = "Network tag the GKE nodes must carry for the firewall rules to apply."
  value       = var.node_network_tag
}
