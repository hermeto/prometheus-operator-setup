mock_provider "google" {
  mock_resource "google_compute_network" {
    override_during = plan
    defaults = {
      id = "projects/demo-project/global/networks/observability-vpc"
    }
  }

  mock_resource "google_compute_subnetwork" {
    override_during = plan
    defaults = {
      id = "projects/demo-project/regions/us-central1/subnetworks/observability-subnet"
    }
  }
}

variables {
  project_id = "demo-project"
  master_authorized_networks = [
    { cidr_block = "203.0.113.10/32", display_name = "admin" },
  ]
}

run "cluster_joins_the_managed_network" {
  command = plan

  assert {
    condition     = module.gke.name == "observability"
    error_message = "Unexpected cluster name."
  }

  assert {
    condition     = module.network.network_id == "projects/demo-project/global/networks/observability-vpc"
    error_message = "The network module must expose its ID to the cluster."
  }
}

run "regional_by_default" {
  command = plan

  assert {
    condition     = local.location == "us-central1"
    error_message = "Without a zone, the cluster must be regional."
  }
}

run "zonal_when_zone_is_set" {
  command = plan

  variables {
    zone = "us-central1-a"
  }

  assert {
    condition     = local.location == "us-central1-a"
    error_message = "Setting zone must create a zonal cluster."
  }
}

run "required_apis_are_enabled" {
  command = plan

  assert {
    condition     = alltrue([for s in ["compute.googleapis.com", "container.googleapis.com"] : contains(keys(google_project_service.this), s)])
    error_message = "Compute and Container APIs must be enabled."
  }

  assert {
    condition     = alltrue([for s in google_project_service.this : s.disable_on_destroy == false])
    error_message = "Destroying the stack must not disable project APIs."
  }
}
