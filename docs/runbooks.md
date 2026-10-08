# Runbooks

Runbooks for the alerts defined in [`monitoring/rules`](../monitoring/rules). The alerts shipped with
kube-prometheus-stack link to the upstream [runbooks.prometheus-operator.dev](https://runbooks.prometheus-operator.dev/).

Every runbook answers: what does it mean, what is the impact, how to diagnose, how to fix.

## SampleAppDown

**Meaning**: Prometheus has not scraped any healthy `podinfo` instance for 5 minutes.

**Impact**: the sample application is unavailable, or it is running but cannot be monitored.

**Diagnose**

```bash
kubectl -n demo get deploy,pods,endpoints podinfo
kubectl -n demo describe pods -l app.kubernetes.io/name=podinfo
kubectl -n demo get servicemonitor podinfo -o yaml
```

Prometheus → Status → Targets: look for `serviceMonitor/demo/podinfo` and its last error.

**Fix**

- Pods not ready: check events and logs (`kubectl -n demo logs deploy/podinfo`).
- Pods ready but no target: the ServiceMonitor selector or port name does not match the Service.
- Target present but down: the metrics port (`9797`) is not reachable — check NetworkPolicies.

## SampleAppHighErrorRate

**Meaning**: more than 5% of the requests returned 5xx for 10 minutes.

**Impact**: users see errors.

**Diagnose**: open the *Sample App / Golden Signals* dashboard and correlate with deployments
(`kubectl -n demo rollout history deploy/podinfo`) and logs.

**Fix**: roll back a bad release with `kubectl -n demo rollout undo deploy/podinfo`; otherwise fix the failing dependency.

## SampleAppHighLatency

**Meaning**: the p99 latency has been above 500 ms for 10 minutes.

**Impact**: slow responses for the slowest 1% of requests.

**Diagnose**: check CPU throttling and memory on the dashboard of the namespace
(*Kubernetes / Compute Resources / Namespace (Pods)*) and whether traffic increased.

**Fix**: scale out (`kubectl -n demo scale deploy/podinfo --replicas=4`), raise the CPU request/limit, or fix the
slow code path.
