# network

Custom-mode VPC for a private, VPC-native GKE cluster:

- one regional subnetwork with secondary ranges for Pods and Services and Private Google Access;
- Cloud Router + Cloud NAT, so private nodes can pull images;
- firewall limited to traffic from the VPC's own ranges, plus optional SSH through Identity-Aware Proxy;
- VPC flow logs (on by default).

```hcl
module "network" {
  source = "../../modules/network"

  project_id = "my-project"
  region     = "us-central1"
  name       = "observability"
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
| [google_compute_firewall.allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Prefix used to name every network resource. | `string` | n/a | yes |
| project_id | GCP project that hosts the network. | `string` | n/a | yes |
| region | Region of the subnetwork, Cloud Router and Cloud NAT. | `string` | n/a | yes |
| enable_flow_logs | Enable VPC flow logs on the subnetwork (security auditing). Disable to save cost on throwaway projects. | `bool` | `true` | no |
| enable_iap_ssh | Allow SSH to the nodes only from Google's Identity-Aware Proxy range (35.235.240.0/20). | `bool` | `false` | no |
| node_network_tag | Network tag carried by the GKE nodes, used to scope firewall rules. | `string` | `"gke-node"` | no |
| pods_cidr | Secondary range used for Pod IPs (VPC-native cluster). | `string` | `"10.20.0.0/16"` | no |
| services_cidr | Secondary range used for Service IPs (VPC-native cluster). | `string` | `"10.30.0.0/20"` | no |
| subnet_cidr | Primary range of the subnetwork, used by the GKE nodes. | `string` | `"10.10.0.0/20"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| network_id | ID of the VPC network. |
| network_name | Name of the VPC network. |
| node_network_tag | Network tag the GKE nodes must carry for the firewall rules to apply. |
| pods_range_name | Name of the secondary range for Pods. |
| services_range_name | Name of the secondary range for Services. |
| subnetwork_id | ID of the subnetwork used by the GKE nodes. |
| subnetwork_name | Name of the subnetwork used by the GKE nodes. |
<!-- END_TF_DOCS -->