terraform {
  required_version = ">= 1.9.0"

  # Partial configuration: pass bucket and prefix with -backend-config=backend.hcl.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.3"
    }
    # Used by modules/monitoring; pinned here so every environment gets the same version.
    # tflint-ignore: terraform_unused_required_providers
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
