terraform {
  required_version = ">= 1.9.0"

  # Partial configuration: pass bucket and prefix with -backend-config=backend.hcl.
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
  }
}
