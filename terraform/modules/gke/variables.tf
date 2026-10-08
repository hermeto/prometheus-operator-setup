variable "project_id" {
  description = "GCP project that hosts the cluster."
  type        = string
}

variable "name" {
  description = "Cluster name."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.name))
    error_message = "name must be a lowercase RFC1035 label of at most 40 characters."
  }
}

variable "location" {
  description = "Region (regional, highly available control plane) or zone (zonal, cheaper) of the cluster."
  type        = string
}

variable "node_locations" {
  description = "Zones for the nodes. Empty uses the default zones of the location."
  type        = list(string)
  default     = []
}

variable "network_id" {
  description = "ID of the VPC network the cluster joins."
  type        = string
}

variable "subnetwork_id" {
  description = "ID of the subnetwork the nodes use."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for Pod IPs."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for Service IPs."
  type        = string
}

variable "release_channel" {
  description = "GKE release channel that drives control plane and node upgrades."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR or STABLE."
  }
}

variable "master_ipv4_cidr_block" {
  description = "/28 range for the private control plane endpoint."
  type        = string
  default     = "172.16.0.0/28"

  validation {
    condition     = can(cidrhost(var.master_ipv4_cidr_block, 0)) && endswith(var.master_ipv4_cidr_block, "/28")
    error_message = "master_ipv4_cidr_block must be a valid /28 IPv4 CIDR block."
  }
}

variable "enable_private_endpoint" {
  description = "Expose the control plane only on its private IP. Requires a bastion, VPN or Interconnect to run Terraform/kubectl."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to reach the control plane endpoint. Keep it as narrow as possible."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []

  validation {
    condition     = alltrue([for n in var.master_authorized_networks : can(cidrhost(n.cidr_block, 0))])
    error_message = "Every master_authorized_networks.cidr_block must be a valid IPv4 CIDR block."
  }
}

variable "node_network_tag" {
  description = "Network tag applied to the nodes (matches the network module firewall rules)."
  type        = string
  default     = "gke-node"
}

variable "machine_type" {
  description = "Machine type of the nodes. kube-prometheus-stack needs at least 2 vCPU / 8 GB in total."
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Boot disk size of each node."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= 20
    error_message = "disk_size_gb must be at least 20."
  }
}

variable "disk_type" {
  description = "Boot disk type of each node."
  type        = string
  default     = "pd-balanced"
}

variable "spot" {
  description = "Use Spot VMs for the node pool. Cheaper, but nodes can be reclaimed at any time."
  type        = bool
  default     = false
}

variable "min_node_count" {
  description = "Minimum nodes per zone for the autoscaler."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum nodes per zone for the autoscaler."
  type        = number
  default     = 3

  validation {
    condition     = var.max_node_count >= 1
    error_message = "max_node_count must be at least 1."
  }
}

variable "deletion_protection" {
  description = "Block `terraform destroy` of the cluster. Disable it explicitly before tearing down."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to the cluster and nodes."
  type        = map(string)
  default     = {}
}

variable "maintenance_start_time" {
  description = "Start of the daily maintenance window, in UTC (HH:MM)."
  type        = string
  default     = "03:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_start_time))
    error_message = "maintenance_start_time must use the HH:MM format."
  }
}
