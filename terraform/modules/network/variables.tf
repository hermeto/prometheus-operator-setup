variable "project_id" {
  description = "GCP project that hosts the network."
  type        = string
}

variable "region" {
  description = "Region of the subnetwork, Cloud Router and Cloud NAT."
  type        = string
}

variable "name" {
  description = "Prefix used to name every network resource."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,40}[a-z0-9])?$", var.name))
    error_message = "name must be a lowercase RFC1035 label of at most 42 characters."
  }
}

variable "subnet_cidr" {
  description = "Primary range of the subnetwork, used by the GKE nodes."
  type        = string
  default     = "10.10.0.0/20"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "pods_cidr" {
  description = "Secondary range used for Pod IPs (VPC-native cluster)."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a valid IPv4 CIDR block."
  }
}

variable "services_cidr" {
  description = "Secondary range used for Service IPs (VPC-native cluster)."
  type        = string
  default     = "10.30.0.0/20"

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a valid IPv4 CIDR block."
  }
}

variable "enable_iap_ssh" {
  description = "Allow SSH to the nodes only from Google's Identity-Aware Proxy range (35.235.240.0/20)."
  type        = bool
  default     = false
}

variable "node_network_tag" {
  description = "Network tag carried by the GKE nodes, used to scope firewall rules."
  type        = string
  default     = "gke-node"
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs on the subnetwork (security auditing). Disable to save cost on throwaway projects."
  type        = bool
  default     = true
}
