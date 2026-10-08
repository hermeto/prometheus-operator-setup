# Contributing

## Workflow

1. Create a branch from `master`.
2. Install the hooks once: `pre-commit install` ([pre-commit](https://pre-commit.com/)).
3. Make the change, then run the checks CI runs:

   ```bash
   make check   # fmt, validate, tflint, terraform test, promtool, dashboards, helm render, shellcheck, trivy
   make e2e     # optional locally, always in CI: kind + terraform apply + smoke tests
   ```

4. Open a pull request. Both the `ci` and `e2e` workflows must pass.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`,
`chore:`...). Add a line to [CHANGELOG.md](CHANGELOG.md) under *Unreleased* for user-visible changes.

## Conventions

- **Terraform**: one concern per module; every variable has a `description`, a `type` and, where it makes sense, a
  `validation`. Modules declare provider *ranges*; environments pin versions and commit `.terraform.lock.hcl`.
- **Tests**: a new behaviour or security property gets a `run` block in the module's `tests/*.tftest.hcl`. A new
  alert gets a `promtool` test in `monitoring/tests` and a runbook in `docs/runbooks.md`.
- **Docs**: module READMEs are generated with [terraform-docs](https://terraform-docs.io/) (the pre-commit hook
  updates them); edit only the text above `<!-- BEGIN_TF_DOCS -->`.
- **Secrets**: never commit credentials, tfvars or kubeconfigs. Pass secrets with `TF_VAR_*` environment variables.
  `gitleaks` runs in pre-commit.

## Upgrading the charts

Bump `chart_version` and `crds_chart_version` together in `terraform/modules/monitoring/variables.tf`. The CRDs
chart version must ship the CRDs of the operator bundled with the stack chart (compare the `appVersion` of both).
