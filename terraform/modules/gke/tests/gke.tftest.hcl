mock_provider "google" {
  mock_resource "google_service_account" {
    override_during = plan
    defaults = {
      email  = "observability-nodes@demo-project.iam.gserviceaccount.com"
      member = "serviceAccount:observability-nodes@demo-project.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id          = "demo-project"
  name                = "observability"
  location            = "us-central1"
  network_id          = "projects/demo-project/global/networks/observability-vpc"
  subnetwork_id       = "projects/demo-project/regions/us-central1/subnetworks/observability-subnet"
  pods_range_name     = "observability-pods"
  services_range_name = "observability-services"
  master_authorized_networks = [
    { cidr_block = "203.0.113.0/24", display_name = "office" },
  ]
}

run "cluster_is_private_and_vpc_native" {
  command = plan

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes
    error_message = "Nodes must not have public IPs."
  }

  assert {
    condition     = google_container_cluster.this.ip_allocation_policy[0].cluster_secondary_range_name == "observability-pods"
    error_message = "The cluster must use the Pods secondary range."
  }

  assert {
    condition     = google_container_cluster.this.network == var.network_id && google_container_cluster.this.subnetwork == var.subnetwork_id
    error_message = "The cluster must join the provided network, not the default one."
  }

  assert {
    condition     = length(google_container_cluster.this.master_authorized_networks_config[0].cidr_blocks) == 1
    error_message = "master_authorized_networks must be applied."
  }
}

run "cluster_security_baseline" {
  command = plan

  assert {
    condition     = google_container_cluster.this.workload_identity_config[0].workload_pool == "demo-project.svc.id.goog"
    error_message = "Workload Identity must be enabled."
  }

  assert {
    condition     = google_container_cluster.this.enable_shielded_nodes
    error_message = "Shielded nodes must be enabled."
  }

  assert {
    condition     = google_container_cluster.this.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Dataplane V2 (network policy enforcement) must be enabled."
  }

  assert {
    condition     = google_container_cluster.this.deletion_protection
    error_message = "Deletion protection must be on by default."
  }

  assert {
    condition     = google_container_cluster.this.monitoring_config[0].managed_prometheus[0].enabled == false
    error_message = "Managed Prometheus must be off; kube-prometheus-stack collects the metrics."
  }
}

run "node_pool_baseline" {
  command = plan

  assert {
    condition     = google_container_node_pool.primary.node_config[0].workload_metadata_config[0].mode == "GKE_METADATA"
    error_message = "Nodes must use the GKE metadata server (Workload Identity)."
  }

  assert {
    condition     = google_container_node_pool.primary.node_config[0].shielded_instance_config[0].enable_secure_boot
    error_message = "Secure boot must be enabled."
  }

  assert {
    condition     = google_container_node_pool.primary.node_config[0].service_account == "observability-nodes@demo-project.iam.gserviceaccount.com"
    error_message = "Nodes must run as the dedicated service account, not the default compute one."
  }

  assert {
    condition     = google_container_node_pool.primary.node_config[0].spot == false
    error_message = "Spot VMs must be opt-in."
  }

  assert {
    condition     = google_container_node_pool.primary.upgrade_settings[0].max_unavailable == 0
    error_message = "Upgrades must surge instead of taking capacity away."
  }
}

run "node_service_account_is_least_privilege" {
  command = plan

  assert {
    condition     = !contains([for m in google_project_iam_member.nodes : m.role], "roles/editor")
    error_message = "The node service account must not be a project editor."
  }

  assert {
    condition     = length(google_project_iam_member.nodes) == 5
    error_message = "Unexpected set of node service account roles."
  }
}

run "spot_nodes_can_be_enabled" {
  command = plan

  variables {
    spot = true
  }

  assert {
    condition     = google_container_node_pool.primary.node_config[0].spot
    error_message = "spot = true must create Spot nodes."
  }
}

run "rejects_wrong_master_cidr_size" {
  command = plan

  variables {
    master_ipv4_cidr_block = "172.16.0.0/24"
  }

  expect_failures = [var.master_ipv4_cidr_block]
}

run "rejects_unknown_release_channel" {
  command = plan

  variables {
    release_channel = "NIGHTLY"
  }

  expect_failures = [var.release_channel]
}

run "long_names_produce_a_valid_service_account_id" {
  command = plan

  variables {
    name = "a-very-long-cluster-name-abcd"
  }

  assert {
    condition     = can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", google_service_account.nodes.account_id))
    error_message = "The node service account id must be a valid GCP account id."
  }
}
