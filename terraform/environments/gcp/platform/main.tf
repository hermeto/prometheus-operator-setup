/**
 * Platform stack: project APIs, network and the GKE cluster.
 * The monitoring stack lives in ../monitoring with its own state, so a broken
 * Helm release can never block (or be destroyed by) infrastructure changes.
 */

locals {
  location = coalesce(var.zone, var.region)
}

resource "google_project_service" "this" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source = "../../../modules/network"

  project_id     = var.project_id
  region         = var.region
  name           = var.name
  subnet_cidr    = var.subnet_cidr
  pods_cidr      = var.pods_cidr
  services_cidr  = var.services_cidr
  enable_iap_ssh = var.enable_iap_ssh

  depends_on = [google_project_service.this]
}

module "gke" {
  source = "../../../modules/gke"

  project_id                 = var.project_id
  name                       = var.name
  location                   = local.location
  network_id                 = module.network.network_id
  subnetwork_id              = module.network.subnetwork_id
  pods_range_name            = module.network.pods_range_name
  services_range_name        = module.network.services_range_name
  node_network_tag           = module.network.node_network_tag
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks
  release_channel            = var.release_channel
  machine_type               = var.machine_type
  min_node_count             = var.min_node_count
  max_node_count             = var.max_node_count
  spot                       = var.spot
  deletion_protection        = var.deletion_protection
  labels                     = var.labels
}
