# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.0] - 2026-10-07

Complete rewrite. Not compatible with 1.x state: create new stacks and migrate workloads.

### Added

- `network`, `gke` and `monitoring` Terraform modules with `terraform test` suites (mocked providers).
- Separate `gcp/platform` and `gcp/monitoring` stacks with remote state in GCS, and a `local` stack for kind.
- Private, hardened GKE cluster: authorized networks, Workload Identity, Shielded Nodes, Dataplane V2, dedicated
  node service account, release channel, maintenance window, autoscaling, optional Spot VMs, deletion protection.
- kube-prometheus-stack 92 with CRDs managed by the `prometheus-operator-crds` release, persistent storage,
  retention by size, `cluster` external label and cluster-wide discovery of monitors and rules.
- Alertmanager routing with an optional Slack receiver whose webhook is read from a Secret.
- Prometheus rules with `promtool` unit tests, a Grafana dashboard and an instrumented sample application.
- `make check` (fmt, validate, tflint, terraform test, promtool, helm render + kubeconform + amtool, shellcheck,
  trivy) and `make e2e` (kind + Terraform + smoke tests), both in GitHub Actions.
- pre-commit hooks, Renovate, terraform-docs, architecture/operations/runbook documentation.

### Changed

- Terraform 0.11 syntax → Terraform ≥ 1.9; Helm 2/Tiller → Helm 3 provider; deprecated `stable/prometheus-operator`
  chart → `prometheus-community/kube-prometheus-stack`.
- The cluster now actually joins the VPC created by the project (it used the `default` network before).

### Removed

- Tiller and its `cluster-admin` binding.
- Basic-auth credentials, the committed service-account key and kubeconfig, git-crypt.
- Firewall rules open to `0.0.0.0/0` on ports 22 and 6443.
- `kubectl apply` of CRDs from the unpinned upstream `master` branch.

## [1.0.0] - 2019-05-08

- Initial GKE + Helm 2 + prometheus-operator setup.
