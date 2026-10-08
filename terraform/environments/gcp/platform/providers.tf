# Credentials come from Application Default Credentials:
# `gcloud auth application-default login` locally, Workload Identity Federation in CI.
provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    managed-by = "terraform"
    stack      = "observability-platform"
  }
}
