variable "project_id" {
  description = "GCP project that hosts the platform."
  type        = string
}

variable "region" {
  description = "Region of the network and, for regional clusters, of the control plane."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for a zonal cluster (one control plane, cheaper). null creates a regional cluster."
  type        = string
  default     = null
}

variable "name" {
  description = "Name of the cluster and prefix of the network resources."
  type        = string
  default     = "observability"
}

variable "subnet_cidr" {
  description = "Primary range of the node subnetwork."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for Pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for Services."
  type        = string
  default     = "10.30.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "/28 range of the private control plane."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to reach the control plane (your office/VPN/CI egress IPs)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"
}

variable "machine_type" {
  description = "Machine type of the nodes."
  type        = string
  default     = "e2-standard-2"
}

variable "min_node_count" {
  description = "Minimum nodes per zone."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone."
  type        = number
  default     = 3
}

variable "spot" {
  description = "Use Spot VMs (cheaper, can be reclaimed). Good for non-production."
  type        = bool
  default     = false
}

variable "enable_iap_ssh" {
  description = "Allow SSH to nodes through Identity-Aware Proxy."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Block cluster deletion. Set to false and apply before `terraform destroy`."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Extra labels for the cluster and nodes."
  type        = map(string)
  default     = {}
}
