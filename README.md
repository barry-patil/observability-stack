# Observability Stack

Monitoring is the thing that tells you about problems before users do. I've set up variations of this stack at three different companies now, and the approach here is what I've landed on after seeing what actually gets used during incidents and what ends up ignored.

The stack is Prometheus + Grafana for Kubernetes and application metrics, CloudWatch for AWS-native services and EKS control plane logs, and DataDog for APM and distributed tracing where the team has it licensed. Alertmanager routes to Slack for warnings and PagerDuty for critical.

## What's in here

```
prometheus/
  rules/          — Alerting rules for pods, nodes, deployments
  scrape_configs/ — Custom scrape jobs for non-standard endpoints

grafana/
  dashboards/     — Pre-built dashboard JSON for EKS, app SLIs, cost

alertmanager/
  config.yml      — Routing: warnings → #alerts-k8s, critical → #oncall + PagerDuty

runbooks/         — Step-by-step investigation guides, linked from alert annotations

datadog/          — Agent config and custom metric definitions

terraform/        — Deploys kube-prometheus-stack and CloudWatch alarms
```

## Alert philosophy

Every alert has a runbook link in its annotation. When an alert fires at 2 AM, the on-call engineer should be able to follow the runbook without needing to ping someone who knows the system.

Alerts are grouped by namespace and alert name. The inhibit rule at the bottom of `alertmanager/config.yml` suppresses pod-level alerts when the underlying node is down — this prevents getting 20 Slack messages about pods when the actual problem is one node.

## Deploying

```bash
# Deploy Prometheus + Grafana to the cluster
cd terraform
terraform init
terraform apply -var="cluster_name=pratik-prod" -var="grafana_admin_password=<password>"

# Apply custom Prometheus rules
kubectl apply -f prometheus/rules/ -n monitoring

# Apply Alertmanager config (after setting env vars)
envsubst < alertmanager/config.yml | kubectl create secret generic alertmanager-kube-prometheus-stack-alertmanager \
  --from-file=alertmanager.yaml=/dev/stdin -n monitoring --dry-run=client -o yaml | kubectl apply -f -
```

## Grafana dashboards

Import the JSONs from `grafana/dashboards/` directly in Grafana (Dashboards → Import). The EKS overview dashboard shows node CPU/memory, pod count by namespace, and PVC usage. The SLI dashboard tracks error rate, latency p50/p95/p99, and request throughput per service.

## SLI/SLO definitions

I use these as the baseline for any service:

| SLI | Target | Alert threshold |
|-----|--------|-----------------|
| Availability (2xx/total) | 99.9% | < 99.5% for 5m |
| Latency p95 | < 500ms | > 800ms for 5m |
| Error rate | < 0.1% | > 1% for 5m |

These are deliberately conservative starting points. The right numbers depend on the service — internal tooling can have looser targets than customer-facing APIs.

---

## Architecture

The full architecture diagram is in [architecture.drawio](./architecture.drawio). Open it at [app.diagrams.net](https://app.diagrams.net) — File → Open from Device → select the file.
