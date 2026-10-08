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

variables {
  project_id = "demo-project"
}

run "gke_specific_settings" {
  command = plan

  assert {
    condition     = yamldecode(module.monitoring.helm_values[2]).kubeDns.enabled && !yamldecode(module.monitoring.helm_values[2]).coreDns.enabled
    error_message = "GKE runs kube-dns; scraping CoreDNS would leave a target permanently down."
  }

  assert {
    condition     = yamldecode(module.monitoring.helm_values[1]).kubeControllerManager.enabled == false
    error_message = "The managed control plane must not be scraped."
  }

  assert {
    condition     = yamldecode(module.monitoring.helm_values[1]).prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName == "standard-rwo"
    error_message = "Prometheus must persist data on a balanced persistent disk."
  }
}

run "loads_repository_rules_and_dashboards" {
  command = plan

  assert {
    condition     = contains(keys(yamldecode(module.monitoring.helm_values[1]).additionalPrometheusRulesMap), "sample-app")
    error_message = "monitoring/rules/*.yaml must be deployed."
  }

  assert {
    condition     = contains(module.monitoring.dashboard_config_maps, "grafana-dashboard-sample-app")
    error_message = "monitoring/dashboards/*.json must be deployed."
  }
}
