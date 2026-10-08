# Operations

## Accessing the UIs

The stack exposes nothing outside the cluster by default.

```bash
make grafana                                                  # credentials + port-forward to :3000
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kps-alertmanager 9093:9093
```

Read the Grafana credentials directly:

```bash
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
```

To publish Grafana, uncomment the `grafana.ingress` example in
[`terraform/environments/gcp/monitoring/values.yaml`](../terraform/environments/gcp/monitoring/values.yaml), use a
Google-managed certificate and put [Identity-Aware Proxy](https://cloud.google.com/iap/docs/enabling-kubernetes-howto)
in front of it. Never expose Prometheus or Alertmanager without authentication: their APIs allow anyone to read
every metric and silence alerts.

## Notifications

Set the Slack webhook through the environment so it never lands in a file:

```bash
export TF_VAR_alertmanager_slack_webhook_url='https://hooks.slack.com/services/...'
make gcp-monitoring-plan && make gcp-monitoring-apply
```

Test the route end to end by firing an alert by hand:

```bash
kubectl -n monitoring port-forward svc/kps-alertmanager 9093:9093 &
curl -XPOST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"ManualTest","severity":"warning","namespace":"monitoring"}}]'
```

## Upgrades

| What | How |
| --- | --- |
| kube-prometheus-stack | Bump `chart_version` **and** `crds_chart_version` together in `terraform/modules/monitoring/variables.tf` (the CRDs chart must ship the operator version of the stack chart; Renovate groups them). Read the [chart upgrade notes](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#upgrading-chart) for major versions, run `make check`, then plan/apply. |
| GKE | Automatic through the release channel inside the maintenance window. Change `release_channel` to move faster or slower. |
| Terraform providers | `terraform init -upgrade` in each environment, then commit the updated `.terraform.lock.hcl`. |
| kind node image | Bump `kind/cluster.yaml` together with `KIND_VERSION` in `.github/workflows/e2e.yml`. |

The `helm_release` is `atomic`: a failed upgrade rolls back automatically and the apply fails.

## Cost

Rough on-demand prices in `us-central1` (check the [pricing calculator](https://cloud.google.com/products/calculator)):

| Item | Default | Notes |
| --- | --- | --- |
| GKE cluster fee | regional | Set `zone` for a zonal cluster; the free tier covers one zonal cluster per billing account. |
| Nodes | 3 × `e2-standard-2` (1 per zone) | `spot = true` cuts this by 60–90%. |
| Disks | 3 × 50 GB `pd-balanced` + 55 GB PVCs | |
| Cloud NAT | 1 gateway | Plus data processing. |
| Flow logs | 50% sampling | `enable_flow_logs = false` in the network module to disable. |

For a cheap test environment: `zone = "us-central1-a"`, `spot = true`, `max_node_count = 2`.

## Tearing down

```bash
# 1. Allow the cluster to be deleted.
echo 'deletion_protection = false' >> terraform/environments/gcp/platform/terraform.tfvars
make gcp-platform-plan && make gcp-platform-apply
# 2. Destroy monitoring first (it needs the cluster), then the platform.
make gcp-destroy
```

Project APIs stay enabled (`disable_on_destroy = false`), so other workloads in the project are not affected.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Error: Kubernetes cluster unreachable` during the monitoring plan | Your IP is not in `master_authorized_networks`. Add it to the platform tfvars and apply. |
| `TargetDown` firing for a component | Check the target in Prometheus → Status → Targets. On managed control planes, keep `scrape_control_plane = false`. |
| Grafana shows no dashboards | The ConfigMap needs the label `grafana_dashboard: "1"`; check the `grafana-sc-dashboard` sidecar logs. |
| A ServiceMonitor is ignored | It must select the Service by labels and reference a **named** port; check the operator logs. |
| Helm release stuck in `pending-upgrade` | A previous apply was interrupted: `helm -n monitoring rollback kube-prometheus-stack`, then apply again. |
| Prometheus PVC full | Lower `prometheus_retention_size` (keep it ~80% of the volume) or raise `prometheus_storage_size`. |
