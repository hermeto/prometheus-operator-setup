#!/usr/bin/env bash
# End-to-end check of a deployed monitoring stack.
#
# Proves that the whole pipeline works, not just that pods are running:
#   1. every component is rolled out and ready;
#   2. Prometheus is ready and no scrape target is down;
#   3. the sample application (if deployed) is scraped and its rules are loaded;
#   4. Alertmanager receives alerts from Prometheus (the always-firing Watchdog);
#   5. Grafana is healthy, its Prometheus data source works and the dashboards are loaded.
#
# Usage: scripts/smoke-test.sh
# Environment:
#   NAMESPACE          namespace of the stack (default: monitoring)
#   KUBE_CONTEXT       kubeconfig context (default: current context)
#   TIMEOUT            seconds to wait for each condition (default: 300)
#   CHECK_SAMPLE_APP   also check examples/sample-app (default: true)
set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"
TIMEOUT="${TIMEOUT:-300}"
CHECK_SAMPLE_APP="${CHECK_SAMPLE_APP:-true}"

kubectl_args=()
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  kubectl_args+=(--context "$KUBE_CONTEXT")
fi

k() { kubectl "${kubectl_args[@]}" "$@"; }

for bin in kubectl curl jq; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done

pass() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

# retry <description> <command...>: runs the command every 5s until it succeeds or TIMEOUT expires.
retry() {
  local description="$1"; shift
  local deadline=$((SECONDS + TIMEOUT))
  until "$@" >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      echo "last attempt output:" >&2
      "$@" >&2 || true
      fail "$description (timed out after ${TIMEOUT}s)"
    fi
    sleep 5
  done
  pass "$description"
}

pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT

# port_forward <service> <service port> <local port>
port_forward() {
  k -n "$NAMESPACE" port-forward "svc/$1" "$3:$2" >/dev/null 2>&1 &
  pids+=($!)
  retry "port-forward to svc/$1" curl -fsS -o /dev/null "http://127.0.0.1:$3/"
}

step "Rollout"
for deploy in kps-operator kube-state-metrics grafana; do
  k -n "$NAMESPACE" rollout status "deployment/$deploy" --timeout="${TIMEOUT}s" >/dev/null || fail "deployment/$deploy"
  pass "deployment/$deploy"
done
k -n "$NAMESPACE" rollout status daemonset/node-exporter --timeout="${TIMEOUT}s" >/dev/null || fail "daemonset/node-exporter"
pass "daemonset/node-exporter"
k -n "$NAMESPACE" wait --for=condition=Available --timeout="${TIMEOUT}s" prometheus/kps-prometheus >/dev/null || fail "prometheus/kps-prometheus"
pass "prometheus/kps-prometheus"
k -n "$NAMESPACE" wait --for=condition=Available --timeout="${TIMEOUT}s" alertmanager/kps-alertmanager >/dev/null || fail "alertmanager/kps-alertmanager"
pass "alertmanager/kps-alertmanager"

if [[ "$CHECK_SAMPLE_APP" == "true" ]]; then
  k -n demo rollout status deployment/podinfo --timeout="${TIMEOUT}s" >/dev/null || fail "deployment/podinfo"
  pass "deployment/podinfo"
fi

port_forward kps-prometheus 9090 19090
port_forward kps-alertmanager 9093 19093
port_forward grafana 80 13000

PROM="http://127.0.0.1:19090"
AM="http://127.0.0.1:19093"
GRAFANA="http://127.0.0.1:13000"

step "Prometheus"
retry "Prometheus is ready" curl -fsS "$PROM/-/ready"

no_target_down() {
  local down
  down="$(curl -fsS "$PROM/api/v1/targets?state=active" |
    jq -r '[.data.activeTargets[] | select(.health != "up") | "\(.labels.job) \(.scrapeUrl) \(.health) \(.lastError)"] | .[]')"
  [[ -z "$down" ]] || { echo "$down"; return 1; }
  # Targets start as "unknown"; require at least the core jobs to have been scraped.
  curl -fsS "$PROM/api/v1/query" --data-urlencode 'query=count(up{job=~"kubelet|node-exporter|kube-state-metrics|apiserver"} == 1)' |
    jq -e '.data.result[0].value[1] | tonumber >= 4' >/dev/null
}
retry "every scrape target is up" no_target_down

if [[ "$CHECK_SAMPLE_APP" == "true" ]]; then
  sample_app_up() {
    curl -fsS "$PROM/api/v1/query" --data-urlencode 'query=sum(up{job="podinfo"})' |
      jq -e '.data.result[0].value[1] | tonumber >= 1'
  }
  retry "sample app is scraped (ServiceMonitor)" sample_app_up

  sample_rules_loaded() {
    curl -fsS "$PROM/api/v1/rules" | jq -e '[.data.groups[].name] | index("sample-app.alerts") != null'
  }
  retry "sample app rules are loaded (PrometheusRule)" sample_rules_loaded

  sample_app_not_alerting() {
    curl -fsS "$PROM/api/v1/alerts" | jq -e '[.data.alerts[] | select(.labels.alertname == "SampleAppDown" and .state == "firing")] | length == 0'
  }
  retry "SampleAppDown is not firing" sample_app_not_alerting
fi

step "Alertmanager"
retry "Alertmanager is ready" curl -fsS "$AM/-/ready"
watchdog_delivered() {
  curl -fsS "$AM/api/v2/alerts?filter=alertname%3D%22Watchdog%22" | jq -e 'length >= 1'
}
retry "Prometheus delivers alerts to Alertmanager (Watchdog)" watchdog_delivered

step "Grafana"
user="$(k -n "$NAMESPACE" get secret grafana-admin -o jsonpath='{.data.admin-user}' | base64 -d)"
password="$(k -n "$NAMESPACE" get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)"
grafana() { curl -fsS -u "$user:$password" "$GRAFANA$1"; }

retry "Grafana database is healthy" sh -c "curl -fsS '$GRAFANA/api/health' | jq -e '.database == \"ok\"'"
datasource_ok() { grafana /api/datasources/uid/prometheus/health | jq -e '.status == "OK"'; }
retry "Grafana Prometheus data source works" datasource_ok
dashboards_loaded() {
  grafana "/api/search?type=dash-db&limit=5000" |
    jq -e '(length > 10) and (map(.uid) | index("sample-app") != null)'
}
retry "Grafana dashboards are provisioned (bundled + sample-app)" dashboards_loaded

printf '\n\033[32mAll smoke tests passed.\033[0m\n'
