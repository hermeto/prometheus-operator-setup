/**
 * Private, VPC-native GKE cluster hardened for production use.
 *
 * - Private nodes, control plane reachable only from master_authorized_networks.
 * - Workload Identity instead of node service-account keys.
 * - Dataplane V2 (eBPF) with network policy enforcement.
 * - Shielded nodes, secure boot and a dedicated least-privilege node service account.
 * - Upgrades driven by a release channel inside a maintenance window.
 * - Google Managed Prometheus is disabled: metrics are collected by kube-prometheus-stack.
 */

locals {
  node_sa_roles = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  labels = merge({ managed-by = "terraform" }, var.labels)
}

resource "google_service_account" "nodes" {
  project = var.project_id
  # account_id: 6-30 chars, must not end with a hyphen.
  account_id   = trimsuffix(substr("${var.name}-nodes", 0, 30), "-")
  display_name = "GKE nodes of ${var.name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = local.node_sa_roles

  project = var.project_id
  role    = each.value
  member  = google_service_account.nodes.member
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  network    = var.network_id
  subnetwork = var.subnetwork_id

  # The default pool cannot be configured; a managed pool is created below.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection
  resource_labels     = local.labels
  datapath_provider   = "ADVANCED_DATAPATH"

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  enable_shielded_nodes = true

  # No static credentials: no basic auth, no client certificates. Access goes through IAM.
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = false
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  # Node pools are managed separately; Terraform must not fight the default pool removal.
  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

resource "google_container_node_pool" "primary" {
  project        = var.project_id
  name           = "primary"
  location       = var.location
  cluster        = google_container_cluster.this.name
  node_locations = length(var.node_locations) > 0 ? var.node_locations : null

  initial_node_count = var.min_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = var.disk_type
    image_type      = "COS_CONTAINERD"
    spot            = var.spot
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = [var.node_network_tag]
    labels          = local.labels

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    # The autoscaler owns the node count after creation.
    ignore_changes = [initial_node_count]
  }

  depends_on = [google_project_iam_member.nodes]
}
