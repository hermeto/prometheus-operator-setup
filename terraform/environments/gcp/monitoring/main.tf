/**
 * Monitoring stack on the GKE cluster created by ../platform.
 */

locals {
  monitoring_dir = "${path.root}/../../../../monitoring"
}

module "monitoring" {
  source = "../../../modules/monitoring"

  cluster_name = var.cluster_name

  persistence_enabled       = true
  storage_class_name        = "standard-rwo"
  prometheus_retention      = var.prometheus_retention
  prometheus_retention_size = var.prometheus_retention_size
  prometheus_storage_size   = var.prometheus_storage_size

  # The GKE control plane is managed by Google and cannot be scraped.
  scrape_control_plane = false

  grafana_admin_password         = var.grafana_admin_password
  alertmanager_slack_webhook_url = var.alertmanager_slack_webhook_url
  alertmanager_slack_channel     = var.alertmanager_slack_channel

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
