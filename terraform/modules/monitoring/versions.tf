terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0, < 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }
}
