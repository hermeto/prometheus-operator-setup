provider "google" {
  project = var.project_id
}

# Short-lived OAuth token of the caller (ADC); no kubeconfig or static credentials.
data "google_client_config" "current" {}

data "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.cluster_location
}

locals {
  cluster_host = "https://${data.google_container_cluster.this.endpoint}"
  cluster_ca   = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

provider "kubernetes" {
  host                   = local.cluster_host
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = local.cluster_ca
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster_host
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = local.cluster_ca
  }
}
