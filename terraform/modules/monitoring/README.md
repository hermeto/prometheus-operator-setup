# monitoring

[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
(Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter) on any Kubernetes cluster.

- CRDs are installed and **upgraded** by a separate `prometheus-operator-crds` release (Helm never upgrades CRDs in a chart's `crds/` directory).
- The Grafana admin password and the Slack webhook live in Kubernetes Secrets; they never reach the Helm values or the release history.
- Alertmanager routing: Slack when `alertmanager_slack_webhook_url` is set, `Watchdog`/`InfoInhibitor` never page, severity inhibition.
- Rules (`prometheus_rules`) and dashboards (`grafana_dashboards`) are passed in as code.
- Prometheus selects ServiceMonitors, PodMonitors, Probes, ScrapeConfigs and PrometheusRules from every namespace.
- Persistent storage, retention by time and size, and a `cluster` external label.
- Failed upgrades roll back automatically (`atomic`).

Defaults live in [`values/base.yaml`](values/base.yaml); input-dependent values are generated in `main.tf`;
`values` documents are merged last.

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  cluster_name = "observability"

  prometheus_rules = {
    my-service = file("rules/my-service.rules.yaml")
  }
  grafana_dashboards = {
    "my-service.json" = file("dashboards/my-service.json")
  }
}
```

The module expects configured `kubernetes` and `helm` providers.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| helm | >= 3.0, < 4.0 |
| kubernetes | >= 3.0, < 4.0 |
| random | >= 3.6, < 4.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.crds](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map_v1.dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.alertmanager_slack](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.grafana_admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [random_password.grafana_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cluster_name | Name of the cluster, added as the `cluster` external label to every series and alert. | `string` | n/a | yes |
| alertmanager_slack_channel | Slack channel that receives the notifications. | `string` | `"#alerts"` | no |
| alertmanager_slack_webhook_url | Slack incoming webhook for notifications. null keeps alerts inside Alertmanager only. Stored in a Secret, never in Helm values. | `string` | `null` | no |
| alertmanager_storage_size | Size of the Alertmanager volume. | `string` | `"5Gi"` | no |
| chart_repository | Helm repository of the prometheus-community charts. | `string` | `"https://prometheus-community.github.io/helm-charts"` | no |
| chart_version | Version of the kube-prometheus-stack chart. | `string` | `"92.0.0"` | no |
| crds_chart_version | Version of the prometheus-operator-crds chart. Must ship the CRDs of the operator bundled with chart_version. | `string` | `"32.0.1"` | no |
| grafana_admin_password | Grafana administrator password. null generates a random one, readable from the grafana-admin Secret. | `string` | `null` | no |
| grafana_admin_user | Grafana administrator login. | `string` | `"admin"` | no |
| grafana_dashboards | Extra Grafana dashboards, as a map of file name => dashboard JSON. Loaded by the Grafana sidecar. | `map(string)` | `{}` | no |
| helm_timeout | Seconds Helm waits for the release to become ready. | `number` | `900` | no |
| namespace | Namespace of the monitoring stack. | `string` | `"monitoring"` | no |
| persistence_enabled | Store Prometheus and Alertmanager data on PersistentVolumes. Disable only for throwaway clusters. | `bool` | `true` | no |
| prometheus_retention | How long Prometheus keeps samples. | `string` | `"15d"` | no |
| prometheus_retention_size | Maximum size of the TSDB before old blocks are deleted (e.g. 40GB). Keep it below the volume size. | `string` | `"40GB"` | no |
| prometheus_rules | Extra Prometheus rule files, as a map of name => YAML content in the standard `groups:` format. | `map(string)` | `{}` | no |
| prometheus_storage_size | Size of the Prometheus volume. | `string` | `"50Gi"` | no |
| release_name | Helm release name of kube-prometheus-stack. | `string` | `"kube-prometheus-stack"` | no |
| scrape_control_plane | Scrape kube-controller-manager, kube-scheduler, etcd and kube-proxy. Keep false on managed control planes (GKE), where they are not reachable. | `bool` | `false` | no |
| storage_class_name | StorageClass for the PersistentVolumes. null uses the cluster default. | `string` | `null` | no |
| values | Extra values documents (YAML strings) merged after the module defaults, in order. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| alertmanager_config | Rendered Alertmanager configuration (holds no secrets; the Slack webhook is read from a file). |
| chart_version | Deployed kube-prometheus-stack chart version. |
| dashboard_config_maps | Names of the ConfigMaps holding the Grafana dashboards. |
| grafana_admin_password | Grafana admin password. |
| grafana_admin_secret | Secret holding the Grafana admin credentials (keys admin-user and admin-password). |
| helm_values | Values documents passed to kube-prometheus-stack, in merge order (defaults, generated, extra). |
| namespace | Namespace of the monitoring stack. |
| port_forward_commands | kubectl commands to reach the UIs locally. |
| release_name | Helm release name of kube-prometheus-stack. |
<!-- END_TF_DOCS -->