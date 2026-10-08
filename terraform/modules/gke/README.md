# gke

Private GKE Standard cluster with a production baseline:

- private nodes; control plane reachable only from `master_authorized_networks`;
- no static credentials (no basic auth, no client certificates): access goes through IAM;
- Workload Identity, Shielded Nodes with secure boot, Dataplane V2 (network policy);
- dedicated least-privilege node service account (no `roles/editor`, no default compute SA);
- upgrades through a release channel inside a maintenance window, surge upgrades without capacity loss;
- autoscaled node pool, optionally on Spot VMs;
- Google Managed Prometheus disabled, because kube-prometheus-stack collects the metrics.

```hcl
module "gke" {
  source = "../../modules/gke"

  project_id          = "my-project"
  name                = "observability"
  location            = "us-central1"
  network_id          = module.network.network_id
  subnetwork_id       = module.network.subnetwork_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_authorized_networks = [
    { cidr_block = "203.0.113.10/32", display_name = "admin" },
  ]
}
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9.0 |
| google | >= 8.0, < 9.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Region (regional, highly available control plane) or zone (zonal, cheaper) of the cluster. | `string` | n/a | yes |
| name | Cluster name. | `string` | n/a | yes |
| network_id | ID of the VPC network the cluster joins. | `string` | n/a | yes |
| pods_range_name | Secondary range name for Pod IPs. | `string` | n/a | yes |
| project_id | GCP project that hosts the cluster. | `string` | n/a | yes |
| services_range_name | Secondary range name for Service IPs. | `string` | n/a | yes |
| subnetwork_id | ID of the subnetwork the nodes use. | `string` | n/a | yes |
| deletion_protection | Block `terraform destroy` of the cluster. Disable it explicitly before tearing down. | `bool` | `true` | no |
| disk_size_gb | Boot disk size of each node. | `number` | `50` | no |
| disk_type | Boot disk type of each node. | `string` | `"pd-balanced"` | no |
| enable_private_endpoint | Expose the control plane only on its private IP. Requires a bastion, VPN or Interconnect to run Terraform/kubectl. | `bool` | `false` | no |
| labels | Labels applied to the cluster and nodes. | `map(string)` | `{}` | no |
| machine_type | Machine type of the nodes. kube-prometheus-stack needs at least 2 vCPU / 8 GB in total. | `string` | `"e2-standard-2"` | no |
| maintenance_start_time | Start of the daily maintenance window, in UTC (HH:MM). | `string` | `"03:00"` | no |
| master_authorized_networks | CIDR blocks allowed to reach the control plane endpoint. Keep it as narrow as possible. | ```list(object({ cidr_block = string display_name = string }))``` | `[]` | no |
| master_ipv4_cidr_block | /28 range for the private control plane endpoint. | `string` | `"172.16.0.0/28"` | no |
| max_node_count | Maximum nodes per zone for the autoscaler. | `number` | `3` | no |
| min_node_count | Minimum nodes per zone for the autoscaler. | `number` | `1` | no |
| node_locations | Zones for the nodes. Empty uses the default zones of the location. | `list(string)` | `[]` | no |
| node_network_tag | Network tag applied to the nodes (matches the network module firewall rules). | `string` | `"gke-node"` | no |
| release_channel | GKE release channel that drives control plane and node upgrades. | `string` | `"REGULAR"` | no |
| spot | Use Spot VMs for the node pool. Cheaper, but nodes can be reclaimed at any time. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster_ca_certificate | Base64-encoded public CA certificate of the cluster. |
| endpoint | Control plane endpoint. |
| get_credentials_command | Command that writes a kubeconfig entry for this cluster. |
| location | Cluster location (region or zone). |
| name | Cluster name. |
| node_service_account | Email of the node service account. |
| workload_identity_pool | Workload Identity pool of the cluster. |
<!-- END_TF_DOCS -->