/**
 * Local environment: the full monitoring stack on a kind cluster.
 * Create the cluster first with `make local-up` (see kind/cluster.yaml).
 */

locals {
  monitoring_dir = "${path.root}/../../../monitoring"
}

module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name = var.cluster_name

  # Throwaway cluster: no volumes, short retention.
  persistence_enabled       = false
  prometheus_retention      = "1d"
  prometheus_retention_size = "2GB"

  grafana_admin_password         = var.grafana_admin_password
  alertmanager_slack_webhook_url = var.alertmanager_slack_webhook_url

  prometheus_rules = {
    for f in fileset("${local.monitoring_dir}/rules", "*.yaml") :
    trimsuffix(f, ".rules.yaml") => file("${local.monitoring_dir}/rules/${f}")
  }

  grafana_dashboards = {
    for f in fileset("${local.monitoring_dir}/dashboards", "*.json") :
    f => file("${local.monitoring_dir}/dashboards/${f}")
  }

  values = [file("${path.module}/values.yaml")]
}
