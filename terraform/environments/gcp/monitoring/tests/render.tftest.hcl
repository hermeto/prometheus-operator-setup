mock_provider "google" {
  mock_data "google_container_cluster" {
    defaults = {
      endpoint    = "10.0.0.2"
      master_auth = [{ cluster_ca_certificate = "dGVzdA==" }]
    }
  }
}
mock_provider "helm" {}
mock_provider "kubernetes" {}
mock_provider "random" {
  mock_resource "random_password" {
    override_during = plan
    defaults = {
      result = "generated-password"
    }
  }
}

# Writes the Helm values to build/values/gcp/ for `make test-helm`.
variables {
  project_id = "demo-project"
  render_dir = "../../../../build/values/gcp"
}

run "plan" {
  command = plan
}

run "render" {
  command = apply

  module {
    source = "../../../tests/render-values"
  }

  variables {
    values     = run.plan.helm_values
    output_dir = var.render_dir
  }
}
