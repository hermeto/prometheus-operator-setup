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
  cluster_name = "test-cluster"
}

run "installs_crds_before_the_stack" {
  command = plan

  assert {
    condition     = helm_release.crds.chart == "prometheus-operator-crds" && helm_release.crds.version == var.crds_chart_version
    error_message = "CRDs must come from the pinned prometheus-operator-crds chart."
  }

  assert {
    condition     = helm_release.stack.chart == "kube-prometheus-stack" && helm_release.stack.version == var.chart_version
    error_message = "The stack must use the pinned kube-prometheus-stack chart."
  }

  assert {
    condition     = yamldecode(file("${path.module}/values/base.yaml")).crds.enabled == false
    error_message = "The stack chart must not manage CRDs; the crds release does."
  }

  assert {
    condition     = helm_release.stack.atomic && helm_release.stack.wait
    error_message = "Failed upgrades must roll back automatically."
  }
}

run "credentials_never_reach_helm_values" {
  command = plan

  variables {
    grafana_admin_password         = "s3cr3t-password"
    alertmanager_slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
  }

  assert {
    condition     = alltrue([for v in helm_release.stack.values : !strcontains(v, "s3cr3t-password")])
    error_message = "The Grafana password must not appear in the Helm values."
  }

  assert {
    condition     = alltrue([for v in helm_release.stack.values : !strcontains(v, "hooks.slack.com")])
    error_message = "The Slack webhook must not appear in the Helm values."
  }

  assert {
    condition     = kubernetes_secret_v1.grafana_admin.data["admin-password"] == "s3cr3t-password"
    error_message = "An explicit Grafana password must be stored in the Secret."
  }

  assert {
    condition     = yamldecode(helm_release.stack.values[1]).grafana.admin.existingSecret == "grafana-admin"
    error_message = "Grafana must read its credentials from the Secret."
  }
}

run "generates_grafana_password_when_not_provided" {
  command = plan

  assert {
    condition     = kubernetes_secret_v1.grafana_admin.data["admin-password"] == "generated-password"
    error_message = "A random password must be used when none is provided."
  }
}

run "alerts_stay_in_alertmanager_without_slack" {
  command = plan

  assert {
    condition     = length(kubernetes_secret_v1.alertmanager_slack) == 0
    error_message = "No Slack secret must be created without a webhook."
  }

  assert {
    condition     = yamldecode(output.alertmanager_config).route.receiver == "null"
    error_message = "Without Slack, the default receiver must be null."
  }
}

run "slack_receiver_reads_webhook_from_secret_file" {
  command = plan

  variables {
    alertmanager_slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
    alertmanager_slack_channel     = "#platform-alerts"
  }

  assert {
    condition     = length(kubernetes_secret_v1.alertmanager_slack) == 1
    error_message = "The Slack webhook must be stored in a Secret."
  }

  assert {
    condition     = yamldecode(output.alertmanager_config).route.receiver == "slack"
    error_message = "Slack must be the default receiver."
  }

  assert {
    condition     = yamldecode(output.alertmanager_config).receivers[1].slack_configs[0].api_url_file == "/etc/alertmanager/secrets/alertmanager-slack/webhook-url"
    error_message = "The webhook must be read from the mounted Secret."
  }

  assert {
    condition     = yamldecode(helm_release.stack.values[1]).alertmanager.alertmanagerSpec.secrets == ["alertmanager-slack"]
    error_message = "The Slack Secret must be mounted into Alertmanager."
  }
}

run "watchdog_never_pages" {
  command = plan

  variables {
    alertmanager_slack_webhook_url = "https://hooks.slack.com/services/T000/B000/XXXX"
  }

  assert {
    condition     = contains([for r in yamldecode(output.alertmanager_config).route.routes : r.receiver if contains(r.matchers, "alertname = \"Watchdog\"")], "null")
    error_message = "Watchdog must be routed to the null receiver."
  }
}

run "persistence_and_retention" {
  command = plan

  assert {
    condition     = yamldecode(helm_release.stack.values[1]).prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage == "50Gi"
    error_message = "Prometheus must use a PersistentVolume by default."
  }

  assert {
    condition     = yamldecode(helm_release.stack.values[1]).prometheus.prometheusSpec.externalLabels.cluster == "test-cluster"
    error_message = "Every series must carry the cluster label."
  }
}

run "ephemeral_storage_for_throwaway_clusters" {
  command = plan

  variables {
    persistence_enabled = false
  }

  assert {
    condition     = !can(yamldecode(helm_release.stack.values[1]).prometheus.prometheusSpec.storageSpec)
    error_message = "persistence_enabled = false must not request volumes."
  }
}

run "control_plane_scraping_is_opt_in" {
  command = plan

  assert {
    condition = alltrue([
      for c in ["kubeControllerManager", "kubeScheduler", "kubeEtcd", "kubeProxy"] :
      yamldecode(helm_release.stack.values[1])[c].enabled == false
    ])
    error_message = "Managed control plane components must not be scraped by default."
  }
}

run "rules_and_dashboards_as_code" {
  command = plan

  variables {
    prometheus_rules = {
      example = "groups:\n- name: example\n  rules:\n  - record: job:up:sum\n    expr: sum by (job) (up)\n"
    }
    grafana_dashboards = {
      "example.json" = "{\"title\": \"Example\"}"
    }
  }

  assert {
    condition     = yamldecode(helm_release.stack.values[1]).additionalPrometheusRulesMap.example.groups[0].name == "example"
    error_message = "Rule files must be passed to the chart."
  }

  assert {
    condition     = kubernetes_config_map_v1.dashboards["example.json"].metadata[0].labels.grafana_dashboard == "1"
    error_message = "Dashboards must carry the label watched by the Grafana sidecar."
  }

  assert {
    condition     = kubernetes_config_map_v1.dashboards["example.json"].metadata[0].name == "grafana-dashboard-example"
    error_message = "Unexpected dashboard ConfigMap name."
  }
}

run "extra_values_are_merged_last" {
  command = plan

  variables {
    values = ["grafana:\n  replicas: 2\n"]
  }

  assert {
    condition     = length(helm_release.stack.values) == 3 && yamldecode(helm_release.stack.values[2]).grafana.replicas == 2
    error_message = "Extra values must be appended after the module defaults."
  }
}

run "rejects_invalid_retention" {
  command = plan

  variables {
    prometheus_retention = "fifteen days"
  }

  expect_failures = [var.prometheus_retention]
}
