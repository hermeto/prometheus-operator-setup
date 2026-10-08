/**
 * Network for a private, VPC-native GKE cluster.
 *
 * - Custom-mode VPC (no auto-created subnetworks).
 * - One regional subnetwork with secondary ranges for Pods and Services.
 * - Cloud Router + Cloud NAT so private nodes can pull images and reach the internet.
 * - Least-privilege firewall: internal traffic only, optional SSH through IAP.
 *   GKE manages the control plane -> node rules itself.
 */

locals {
  pods_range_name     = "${var.name}-pods"
  services_range_name = "${var.name}-services"
  iap_source_range    = "35.235.240.0/20"
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = "${var.name}-subnet"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range_name
    ip_cidr_range = var.services_cidr
  }

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_internal" {
  project     = var.project_id
  name        = "${var.name}-allow-internal"
  network     = google_compute_network.this.id
  description = "Node, Pod and Service traffic inside the VPC."
  direction   = "INGRESS"

  source_ranges = [var.subnet_cidr, var.pods_cidr, var.services_cidr]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  count = var.enable_iap_ssh ? 1 : 0

  project     = var.project_id
  name        = "${var.name}-allow-iap-ssh"
  network     = google_compute_network.this.id
  description = "SSH to GKE nodes only through Identity-Aware Proxy."
  direction   = "INGRESS"

  source_ranges = [local.iap_source_range]
  target_tags   = [var.node_network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
