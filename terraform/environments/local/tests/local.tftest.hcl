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

run "kind_is_ephemeral" {
  command = plan

  assert {
    condition     = !can(yamldecode(module.monitoring.helm_values[1]).prometheus.prometheusSpec.storageSpec)
    error_message = "The kind environment must not request PersistentVolumes."
  }

  assert {
    condition     = yamldecode(module.monitoring.helm_values[2]).prometheus.prometheusSpec.scrapeInterval == "15s"
    error_message = "The local values file must be applied last."
  }
}
