/**
 * Monitoring stack: Prometheus Operator, Prometheus, Alertmanager, Grafana,
 * kube-state-metrics and node-exporter, deployed with kube-prometheus-stack.
 *
 * - CRDs come from their own release (prometheus-operator-crds) so they are upgraded with the chart.
 * - Credentials live in Kubernetes Secrets created here, never in Helm values.
 * - Rules and dashboards are passed in as code.
 */

locals {
  grafana_admin_secret      = "grafana-admin"
  alertmanager_slack_secret = "alertmanager-slack"
  slack_enabled             = nonsensitive(var.alertmanager_slack_webhook_url != null)
  grafana_admin_password    = coalesce(var.grafana_admin_password, random_password.grafana_admin.result)

  alertmanager_config = {
    global = {
      resolve_timeout = "5m"
    }
    route = {
      receiver        = local.slack_enabled ? "slack" : "null"
      group_by        = ["namespace", "alertname"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "12h"
      routes = [
        # Watchdog fires all the time to prove the pipeline works; it is not a page.
        { receiver = "null", matchers = ["alertname = \"Watchdog\""] },
        { receiver = "null", matchers = ["alertname = \"InfoInhibitor\""] },
      ]
    }
    inhibit_rules = [
      {
        source_matchers = ["severity = \"critical\""]
        target_matchers = ["severity =~ \"warning|info\""]
        equal           = ["namespace", "alertname"]
      },
      {
        source_matchers = ["severity = \"warning\""]
        target_matchers = ["severity = \"info\""]
        equal           = ["namespace", "alertname"]
      },
      {
        source_matchers = ["alertname = \"InfoInhibitor\""]
        target_matchers = ["severity = \"info\""]
        equal           = ["namespace"]
      },
    ]
    receivers = concat(
      [{ name = "null" }],
      local.slack_enabled ? [{
        name = "slack"
        slack_configs = [{
          api_url_file  = "/etc/alertmanager/secrets/${local.alertmanager_slack_secret}/webhook-url"
          channel       = var.alertmanager_slack_channel
          send_resolved = true
          title         = "[{{ .Status | toUpper }}{{ if eq .Status \"firing\" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }} ({{ .CommonLabels.cluster }})"
          text          = "{{ range .Alerts }}*{{ .Labels.severity }}* {{ .Annotations.summary }}\n{{ .Annotations.description }}\n{{ end }}"
        }]
      }] : [],
    )
    templates = ["/etc/alertmanager/config/*.tmpl"]
  }

  # Omit storageClassName entirely to fall back to the cluster default class.
  storage_class = var.storage_class_name == null ? {} : { storageClassName = var.storage_class_name }

  persistence = {
    prometheus = var.persistence_enabled ? {
      volumeClaimTemplate = {
        spec = merge(local.storage_class, {
          accessModes = ["ReadWriteOnce"]
          resources   = { requests = { storage = var.prometheus_storage_size } }
        })
      }
    } : null
    alertmanager = var.persistence_enabled ? {
      volumeClaimTemplate = {
        spec = merge(local.storage_class, {
          accessModes = ["ReadWriteOnce"]
          resources   = { requests = { storage = var.alertmanager_storage_size } }
        })
      }
    } : null
  }

  generated_values = {
    kubeControllerManager = { enabled = var.scrape_control_plane }
    kubeScheduler         = { enabled = var.scrape_control_plane }
    kubeEtcd              = { enabled = var.scrape_control_plane }
    kubeProxy             = { enabled = var.scrape_control_plane }

    prometheus = {
      prometheusSpec = merge(
        {
          retention      = var.prometheus_retention
          retentionSize  = var.prometheus_retention_size
          externalLabels = { cluster = var.cluster_name }
        },
        local.persistence.prometheus == null ? {} : { storageSpec = local.persistence.prometheus },
      )
    }

    alertmanager = {
      config = local.alertmanager_config
      alertmanagerSpec = merge(
        { secrets = local.slack_enabled ? [local.alertmanager_slack_secret] : [] },
        local.persistence.alertmanager == null ? {} : { storage = local.persistence.alertmanager },
      )
    }

    grafana = {
      admin = {
        existingSecret = local.grafana_admin_secret
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }
      # Roll Grafana when the admin password changes; the hash reveals nothing.
      podAnnotations = {
        "checksum/admin-secret" = nonsensitive(sha256(local.grafana_admin_password))
      }
    }

    additionalPrometheusRulesMap = {
      for name, content in var.prometheus_rules : name => yamldecode(content)
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      # node-exporter needs hostNetwork, hostPID and hostPath mounts.
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = local.grafana_admin_secret
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    admin-user     = var.grafana_admin_user
    admin-password = local.grafana_admin_password
  }
}

resource "kubernetes_secret_v1" "alertmanager_slack" {
  count = local.slack_enabled ? 1 : 0

  metadata {
    name      = local.alertmanager_slack_secret
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    webhook-url = var.alertmanager_slack_webhook_url
  }
}

resource "kubernetes_config_map_v1" "dashboards" {
  for_each = var.grafana_dashboards

  metadata {
    name      = "grafana-dashboard-${trimsuffix(each.key, ".json")}"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    (each.key) = each.value
  }
}

resource "helm_release" "crds" {
  name       = "prometheus-operator-crds"
  repository = var.chart_repository
  chart      = "prometheus-operator-crds"
  version    = var.crds_chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  timeout    = 300
  wait       = true
}

resource "helm_release" "stack" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = "kube-prometheus-stack"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name

  timeout         = var.helm_timeout
  wait            = true
  atomic          = true
  cleanup_on_fail = true
  max_history     = 10

  values = concat(
    [
      file("${path.module}/values/base.yaml"),
      yamlencode(local.generated_values),
    ],
    var.values,
  )

  depends_on = [
    helm_release.crds,
    kubernetes_secret_v1.grafana_admin,
    kubernetes_secret_v1.alertmanager_slack,
  ]
}
