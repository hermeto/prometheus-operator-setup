# Security policy

## Reporting a vulnerability

Please do **not** open a public issue. Email hermeto.romano@gmail.com with a description and steps to reproduce.
You will get an answer within 7 days.

## Design

- No credentials in the repository: GCP access uses Application Default Credentials or Workload Identity Federation,
  Kubernetes access uses short-lived OAuth tokens, and application secrets are passed as `TF_VAR_*` variables and
  stored in Kubernetes Secrets.
- Terraform state holds generated secrets (Grafana password); keep the state bucket private, versioned and
  encrypted, and restrict who can read it.
- The cluster has private nodes, an authorized-networks-only control plane, no basic auth or client certificates,
  Workload Identity and Shielded Nodes. See [docs/architecture.md](docs/architecture.md).

## Credentials from earlier versions

Before 2.0.0 this repository stored a GCP service-account key, a kubeconfig and an Alertmanager configuration
(encrypted with git-crypt), plus a cluster admin password in plain text in `variables.tf`. They were removed from
the tree in 2.0.0 but **remain in the Git history**. Treat them as compromised:

1. Delete the old service-account key: `gcloud iam service-accounts keys list --iam-account=<sa>` then
   `gcloud iam service-accounts keys delete <key-id> --iam-account=<sa>`.
2. Delete the old cluster (`getup-cluster`) if it still exists; its basic-auth password is public.
3. Rotate the Slack webhook that was in `helm/alertmanager.values.yaml`.
4. Optionally rewrite the history with [git filter-repo](https://github.com/newren/git-filter-repo) and force-push
   (coordinate with every clone first).
