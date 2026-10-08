SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS += --no-print-directory

# ----------------------------------------------------------------------------
# Settings (override on the command line: make e2e KIND_CLUSTER=foo)
# ----------------------------------------------------------------------------
KIND_CLUSTER     ?= observability
KUBE_CONTEXT     ?= kind-$(KIND_CLUSTER)
K8S_VERSION      ?= 1.37.0
PROMETHEUS_IMAGE ?= prom/prometheus:v3.15.0
CHART_REPO       ?= https://prometheus-community.github.io/helm-charts
# Single source of truth: the monitoring module defaults.
CHART_VERSION    := $(shell awk '/variable "chart_version"/{f=1} f && /default/{gsub(/"/,"",$$3); print $$3; exit}' terraform/modules/monitoring/variables.tf)
BUILD_DIR        := build
CHART_DIR        := $(BUILD_DIR)/charts/kube-prometheus-stack-$(CHART_VERSION)

# GCP stacks
GCP_PLATFORM     := terraform/environments/gcp/platform
GCP_MONITORING   := terraform/environments/gcp/monitoring
BACKEND_CONFIG   ?= backend.hcl
VAR_FILE         ?= terraform.tfvars

LOCAL_ENV        := terraform/environments/local
TF_ROOTS         := $(LOCAL_ENV) $(GCP_PLATFORM) $(GCP_MONITORING)
TF_MODULES       := $(wildcard terraform/modules/*) terraform/tests/render-values
TF_DIRS          := $(TF_MODULES) $(TF_ROOTS)

KUBECONFORM_SCHEMAS := -schema-location default \
	-schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Static checks (no cloud account, no cluster)

.PHONY: tools
tools: ## Check that the required tools are installed
	@for t in terraform tflint helm kubectl kubeconform shellcheck trivy docker jq; do \
	  if command -v $$t >/dev/null; then printf '  \033[32mok\033[0m      %s\n' "$$t"; else printf '  \033[31mmissing\033[0m %s\n' "$$t"; missing=1; fi; \
	done; exit $${missing:-0}

.PHONY: fmt
fmt: ## Format Terraform code
	terraform fmt -recursive terraform

.PHONY: fmt-check
fmt-check: ## Fail if Terraform code is not formatted
	terraform fmt -recursive -check -diff terraform

.PHONY: init
init: ## Initialise every Terraform directory without a backend
	@for d in $(TF_DIRS); do echo "==> init $$d"; terraform -chdir=$$d init -backend=false -input=false >/dev/null; done

.PHONY: validate
validate: init ## Validate every Terraform directory
	@for d in $(TF_DIRS); do echo "==> validate $$d"; terraform -chdir=$$d validate; done

.PHONY: lint
lint: ## Lint Terraform with tflint (terraform + google rulesets)
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	@for d in $(TF_DIRS); do echo "==> tflint $$d"; tflint --chdir=$$d --config "$(CURDIR)/.tflint.hcl"; done

.PHONY: test-unit
test-unit: init ## Run Terraform tests (mocked providers, no credentials needed)
	@for d in $(TF_DIRS); do \
	  if [ -d $$d/tests ] && ls $$d/tests/*.tftest.hcl >/dev/null 2>&1; then echo "==> terraform test $$d"; terraform -chdir=$$d test; fi; \
	done

.PHONY: test-rules
test-rules: ## Check and unit-test the Prometheus rules with promtool
	docker run --rm -v "$(CURDIR)/monitoring:/monitoring:ro" -w /monitoring/tests --entrypoint promtool $(PROMETHEUS_IMAGE) \
	  check rules $(addprefix ../rules/,$(notdir $(wildcard monitoring/rules/*.yaml)))
	docker run --rm -v "$(CURDIR)/monitoring:/monitoring:ro" -w /monitoring/tests --entrypoint promtool $(PROMETHEUS_IMAGE) \
	  test rules $(notdir $(wildcard monitoring/tests/*.test.yaml))

.PHONY: test-dashboards
test-dashboards: ## Validate the Grafana dashboards (JSON, unique uid, title)
	@for f in monitoring/dashboards/*.json; do \
	  jq -e '(.uid | type == "string" and length > 0) and (.title | type == "string") and (.panels | length > 0)' "$$f" >/dev/null || { echo "invalid dashboard: $$f"; exit 1; }; \
	  echo "  ok $$f"; \
	done
	@dupes=$$(jq -r .uid monitoring/dashboards/*.json | sort | uniq -d); [ -z "$$dupes" ] || { echo "duplicate dashboard uid: $$dupes"; exit 1; }

$(CHART_DIR):
	mkdir -p $(BUILD_DIR)/charts
	helm pull kube-prometheus-stack --repo $(CHART_REPO) --version $(CHART_VERSION) --untar --untardir $(CHART_DIR)-tmp
	mv $(CHART_DIR)-tmp/kube-prometheus-stack $(CHART_DIR) && rm -rf $(CHART_DIR)-tmp

.PHONY: test-helm
test-helm: init $(CHART_DIR) ## Render the chart with the exact Terraform values; validate manifests and Alertmanager config
	rm -rf $(BUILD_DIR)/values
	terraform -chdir=$(LOCAL_ENV) test -filter=tests/render.tftest.hcl
	terraform -chdir=$(GCP_MONITORING) test -filter=tests/render.tftest.hcl
	@for v in $(BUILD_DIR)/values/*; do \
	  name=$$(basename $$v); echo "==> $$name"; \
	  helm template kube-prometheus-stack $(CHART_DIR) --namespace monitoring --kube-version $(K8S_VERSION) \
	    $$(ls $$v/*.yaml | sed 's/^/-f /') > $(BUILD_DIR)/$$name.yaml; \
	  kubeconform -strict -summary -kubernetes-version $(K8S_VERSION) $(KUBECONFORM_SCHEMAS) $(BUILD_DIR)/$$name.yaml; \
	  scripts/check-alertmanager-config.sh $(BUILD_DIR)/$$name.yaml; \
	done
	kubeconform -strict -summary -kubernetes-version $(K8S_VERSION) $(KUBECONFORM_SCHEMAS) examples/sample-app/

.PHONY: test-scripts
test-scripts: ## Lint shell scripts with shellcheck
	shellcheck scripts/*.sh

.PHONY: security
security: ## Scan Terraform and manifests for misconfigurations (trivy)
	trivy config --disable-telemetry --severity MEDIUM,HIGH,CRITICAL --skip-dirs $(BUILD_DIR) --exit-code 1 .

.PHONY: check
check: fmt-check validate lint test-unit test-rules test-dashboards test-helm test-scripts security ## Run every static check (what CI runs)

##@ Local environment (kind)

.PHONY: local-up
local-up: ## Create the kind cluster
	@if kind get clusters 2>/dev/null | grep -qx '$(KIND_CLUSTER)'; then echo "kind cluster $(KIND_CLUSTER) already exists"; \
	else kind create cluster --name $(KIND_CLUSTER) --config kind/cluster.yaml --wait 120s; fi

.PHONY: local-deploy
local-deploy: ## Deploy the monitoring stack on kind with Terraform
	terraform -chdir=$(LOCAL_ENV) init -input=false
	terraform -chdir=$(LOCAL_ENV) apply -input=false -auto-approve -var kube_context=$(KUBE_CONTEXT)

.PHONY: sample-app
sample-app: ## Deploy the instrumented sample application
	kubectl --context $(KUBE_CONTEXT) apply -f examples/sample-app/

.PHONY: smoke
smoke: ## Run the end-to-end smoke tests against the cluster
	KUBE_CONTEXT=$(KUBE_CONTEXT) scripts/smoke-test.sh

.PHONY: e2e
e2e: local-up local-deploy sample-app smoke ## Create kind, deploy everything and run the smoke tests

.PHONY: grafana
grafana: ## Print the Grafana credentials and open a port-forward on http://localhost:3000
	@echo "user:     $$(kubectl --context $(KUBE_CONTEXT) -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-user}' | base64 -d)"
	@echo "password: $$(kubectl --context $(KUBE_CONTEXT) -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
	kubectl --context $(KUBE_CONTEXT) -n monitoring port-forward svc/grafana 3000:80

.PHONY: local-down
local-down: ## Delete the kind cluster and the local Terraform state
	kind delete cluster --name $(KIND_CLUSTER)
	rm -f $(LOCAL_ENV)/terraform.tfstate $(LOCAL_ENV)/terraform.tfstate.backup

##@ Google Cloud (GKE)

.PHONY: gcp-platform-plan
gcp-platform-plan: ## Plan network + GKE (needs backend.hcl and terraform.tfvars in the stack directory)
	terraform -chdir=$(GCP_PLATFORM) init -input=false -backend-config=$(BACKEND_CONFIG)
	terraform -chdir=$(GCP_PLATFORM) plan -input=false -var-file=$(VAR_FILE) -out=tfplan

.PHONY: gcp-platform-apply
gcp-platform-apply: ## Apply the saved platform plan
	terraform -chdir=$(GCP_PLATFORM) apply -input=false tfplan

.PHONY: gcp-monitoring-plan
gcp-monitoring-plan: ## Plan the monitoring stack on GKE
	terraform -chdir=$(GCP_MONITORING) init -input=false -backend-config=$(BACKEND_CONFIG)
	terraform -chdir=$(GCP_MONITORING) plan -input=false -var-file=$(VAR_FILE) -out=tfplan

.PHONY: gcp-monitoring-apply
gcp-monitoring-apply: ## Apply the saved monitoring plan
	terraform -chdir=$(GCP_MONITORING) apply -input=false tfplan

.PHONY: gcp-credentials
gcp-credentials: ## Write a kubeconfig entry for the GKE cluster
	eval "$$(terraform -chdir=$(GCP_PLATFORM) output -raw get_credentials_command)"

.PHONY: gcp-smoke
gcp-smoke: ## Run the smoke tests against GKE (current kubectl context)
	CHECK_SAMPLE_APP=$${CHECK_SAMPLE_APP:-false} KUBE_CONTEXT= scripts/smoke-test.sh

.PHONY: gcp-destroy
gcp-destroy: ## Destroy monitoring, then the platform (set deletion_protection = false and apply first)
	terraform -chdir=$(GCP_MONITORING) destroy -input=false -var-file=$(VAR_FILE)
	terraform -chdir=$(GCP_PLATFORM) destroy -input=false -var-file=$(VAR_FILE)

##@ Housekeeping

.PHONY: clean
clean: ## Remove build output and Terraform caches
	rm -rf $(BUILD_DIR)
	find terraform -type d -name .terraform -prune -exec rm -rf {} +
