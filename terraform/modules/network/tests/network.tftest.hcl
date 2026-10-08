mock_provider "google" {}

variables {
  project_id = "demo-project"
  region     = "us-central1"
  name       = "observability"
}

run "creates_vpc_native_subnet" {
  command = plan

  assert {
    condition     = google_compute_network.this.auto_create_subnetworks == false
    error_message = "The VPC must be custom-mode."
  }

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access
    error_message = "Private Google Access is required for private nodes."
  }

  assert {
    condition = toset([for r in google_compute_subnetwork.this.secondary_ip_range : r.range_name]) == toset([
      "observability-pods",
      "observability-services",
    ])
    error_message = "The subnetwork must expose the Pods and Services secondary ranges."
  }

  assert {
    condition     = output.pods_range_name == "observability-pods" && output.services_range_name == "observability-services"
    error_message = "Range name outputs must match the secondary ranges."
  }
}

run "no_firewall_rule_is_open_to_the_internet" {
  command = plan

  assert {
    condition     = !contains(google_compute_firewall.allow_internal.source_ranges, "0.0.0.0/0")
    error_message = "The internal rule must not accept traffic from the internet."
  }

  assert {
    condition     = length(google_compute_firewall.allow_iap_ssh) == 0
    error_message = "SSH must be disabled by default."
  }
}

run "iap_ssh_is_scoped_to_iap_range_and_node_tag" {
  command = plan

  variables {
    enable_iap_ssh = true
  }

  assert {
    condition     = google_compute_firewall.allow_iap_ssh[0].source_ranges == toset(["35.235.240.0/20"])
    error_message = "SSH must only be reachable from the IAP range."
  }

  assert {
    condition     = google_compute_firewall.allow_iap_ssh[0].target_tags == toset(["gke-node"])
    error_message = "SSH must only target GKE nodes."
  }
}

run "private_nodes_get_egress_through_nat" {
  command = plan

  assert {
    condition     = google_compute_router_nat.this.source_subnetwork_ip_ranges_to_nat == "ALL_SUBNETWORKS_ALL_IP_RANGES"
    error_message = "Cloud NAT must cover node and Pod ranges."
  }
}

run "flow_logs_on_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 1
    error_message = "VPC flow logs must be enabled by default."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    pods_cidr = "10.20.0.0/99"
  }

  expect_failures = [var.pods_cidr]
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "Invalid_Name"
  }

  expect_failures = [var.name]
}
