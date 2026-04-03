# Monitoring Stack (Victoria Metrics + Grafana)

Lightweight monitoring solution using Victoria Metrics for Kubernetes observability.

## Overview

This deployment includes:

- **VMSingle** - Time series database (replaces Prometheus, ~200Mi vs 800Mi)
- **VMAgent** - Lightweight metric scraper
- **VMAlert** - Alert rule evaluation
- **VMAlertmanager** - Alert routing and notifications
- **Grafana** - Metrics visualization and dashboarding
- **Loki Datasource** - Log queries for Kubernetes logs and external device syslog
- **Node Exporter** - Host-level metrics
- **Kube State Metrics** - Kubernetes object metrics

### Why Victoria Metrics?

| Metric            | Prometheus Stack | Victoria Metrics     |
| ----------------- | ---------------- | -------------------- |
| Memory Usage      | ~1.5 GB          | ~400 MB              |
| CPU Usage         | Higher           | 2-5x lower           |
| Disk I/O          | Higher           | Lower (compression)  |
| Query Speed       | Fast             | Faster (optimized)   |
| PromQL Compatible | Yes              | Yes (plus MetricsQL) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Namespace                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  VMSingle    │───→│  Grafana     │    │ VMAlertmanager  │  │
│  │  (Storage)   │    │  (Visualize) │    │  (Alerts)       │  │
│  └──────┬───────┘    └──────────────┘    └────────▲─────────┘  │
│         │                     ▲                    │            │
│         │                     │                    │            │
│  ┌──────▼───────┐      ┌──────┴───────┐    ┌──────┴───────┐   │
│  │  VMAgent     │      │  VMAlert     │────│  VMRules     │   │
│  │  (Scraper)   │      │  (Evaluate)  │    │  (Alert CRD) │   │
│  └──────┬───────┘      └──────────────┘    └──────────────┘   │
│         │ scrapes                                              │
│         ▼                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         VMServiceScrape / VMNodeScrape (CRDs)           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        │                │                │                │
        ▼                ▼                ▼                ▼
  Node Exporter    Kubelet Metrics   API Server     Your Apps
  (host metrics)   (container)       (K8s metrics)  (custom)
```

## Deployment

### GitOps Deployment (Recommended)

This monitoring stack is deployed via **ArgoCD** for continuous GitOps delivery.

```bash
# Deploy via root App-of-Apps
kubectl apply -f kubernetes/applications/root-app.yaml

# Or deploy monitoring directly
kubectl apply -f kubernetes/applications/monitoring/application.yaml

# Check sync status
argocd app get monitoring
```

### Making Changes

1. Edit configuration files in this directory
2. Commit and push to git
3. ArgoCD automatically syncs (or manually: `argocd app sync monitoring`)

## Accessing Grafana

- **URL:** `https://grafana.silverseekers.org`
- **Username:** `admin`
- **Password:** Configured via Sealed Secrets

## Pre-loaded Dashboards

The homelab now favors a curated set of repo-managed dashboards over a larger
mix of generic imports. Key dashboards include:

- `Cluster Overview`
- `Node and Storage Health`
- `Unified Logs`
- `Monitoring Control Plane`
- `Cloud Edge and DNS Automation`
- `Home Automation Operations`
- `Traefik`
- `ArgoCD`
- `Platform Health`
- `DNS Health`
- `Longhorn`
- `Garage Object Storage`
- `Resource Quotas`
- `Kubernetes Pods` (Grafana.com drilldown import)

## Configuration Files

| File                             | Purpose                          |
| -------------------------------- | -------------------------------- |
| `application.yaml`               | ArgoCD Application definition    |
| `vm-operator-values.yaml`        | Victoria Metrics Operator config |
| `vmsingle.yaml`                  | VMSingle (storage) CRD           |
| `vmagent.yaml`                   | VMAgent (scraper) CRD            |
| `vmalert.yaml`                   | VMAlert (alerting) CRD           |
| `vmalertmanager.yaml`            | VMAlertmanager CRD               |
| `vm-scrape-configs.yaml`         | Scrape target configurations     |
| `grafana-values.yaml`            | Grafana Helm values              |
| `templates/dashboards-configmaps.yaml` | Inline custom dashboards and legacy curated dashboards |
| `templates/grafana-dashboard-*.yaml` | JSON-backed curated dashboard wrappers |
| `dashboards/*.json`              | Versioned dashboard JSON sources |
| `node-exporter-values.yaml`      | Node Exporter config             |
| `kube-state-metrics-values.yaml` | Kube State Metrics config        |
| `ingressroute.yaml`              | Traefik IngressRoute for Grafana |

## Components

### VMSingle (Time Series Database)

**Endpoints:**

- Internal: `http://vmsingle-vmsingle.monitoring.svc:8429`
- VMUI: Port-forward to access built-in UI

```bash
kubectl port-forward -n monitoring svc/vmsingle-vmsingle 8429:8429
# Open http://localhost:8429/vmui
```

**Query Examples (PromQL/MetricsQL):**

```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total
```

### VMAgent (Metric Scraper)

Discovers and scrapes metrics from:

- Kubernetes nodes (kubelet, cadvisor)
- Services with `prometheus.io/scrape: "true"` annotations
- VMServiceScrape and VMPodScrape CRDs

### VMAlert (Alert Evaluation)

Evaluates alerting rules defined in VMRule CRDs.

**Create Custom Alert:**

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: my-alerts
  namespace: monitoring
spec:
  groups:
    - name: my-app
      rules:
        - alert: HighMemoryUsage
          expr: container_memory_usage_bytes > 1e9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage detected"
```

### Grafana

**Features:**

- Victoria Metrics datasource (Prometheus compatible)
- Loki datasource for Kubernetes logs plus external device syslog
- Pre-loaded dashboards
- TLS via Traefik IngressRoute
- Persistent storage for dashboards

### External Device Logs

Grafana can also query logs from LAN devices that send `RFC3164` syslog into the
dedicated receiver in `kubernetes/services/syslog-receiver`. Use the existing
Loki datasource and start with a LogQL filter such as `{job="slzb"}`.

## Service Scraping

### Auto-Discovery via Annotations

Add these annotations to your Service or Pod:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

### VMServiceScrape CRD

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: my-app
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
      - my-namespace
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 60s
      path: /metrics
```

## Storage

All components use Longhorn for persistent storage:

| Component      | PVC Size | Purpose             |
| -------------- | -------- | ------------------- |
| VMSingle       | 2Gi      | Metrics data        |
| Grafana        | 5Gi      | Dashboards & config |
| VMAlertmanager | 1Gi      | Alert state         |

## Resource Usage

Expected memory usage after deployment:

| Component                | Memory      |
| ------------------------ | ----------- |
| VMSingle                 | ~200 Mi     |
| VMAgent                  | ~50 Mi      |
| VMAlert                  | ~30 Mi      |
| VMAlertmanager           | ~30 Mi      |
| Grafana                  | ~100 Mi     |
| VM Operator              | ~30 Mi      |
| Node Exporter (per node) | ~10 Mi      |
| Kube State Metrics       | ~20 Mi      |
| **Total**                | **~470 Mi** |

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n monitoring
```

### View VMSingle Logs

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=vmsingle
```

### View Grafana Logs

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### VMAgent Not Scraping Targets

1. Check VMServiceScrape/VMPodScrape exists:

```bash
kubectl get vmservicescrape,vmpodscrape -A
```

2. Check VMAgent targets:

```bash
kubectl port-forward -n monitoring svc/vmagent-vmagent 8429:8429
# Open http://localhost:8429/targets
```

### Grafana panels show “No data” (dashboard-specific)

| Dashboard / area | Typical cause |
| ---------------- | ------------- |
| **Resource Quotas** | PromQL must use `ignoring(type)` when dividing `kube_resourcequota{type="used"}` by `type="hard"` (labels differ only on `type`). |
| **Platform Health — Authelia** | `configMap.telemetry.metrics.enabled` must be `true` in Authelia values (metrics on `:9959`). |
| **Platform Health — Cert-Manager** | `prometheus.enabled: true` on the Jetstack chart (controller exposes `:9402/metrics`). |
| **Platform Health — Velero** | Velero must be scraped (`VMServiceScrape` on `http-monitoring` / `:8085`). |
| **Garage** | Dashboard filters `job="garage"`; scrape config must set that `job` (relabel), not `jobLabel: garage` without a matching Service label. |
| **Unified Logs** | Kubernetes panels require `namespace` and `pod` labels. Device panels require syslog labels like `job`, `device`, `source_host`, and `appname` from the syslog receiver. |
| **Monitoring Control Plane** | Promtail panels require the Promtail scrape to target the `loki` namespace. If they are empty, verify the `VMServiceScrape` selector and namespace match the deployment. |

### Grafana Dashboard Not Loading

1. Check datasource connection:

   - Grafana → Configuration → Data Sources → VictoriaMetrics
   - Click "Test" button

2. Verify VMSingle is running:

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=vmsingle
```

## Secrets Management

Grafana credentials are managed via **Sealed Secrets**:

```yaml
# secrets.yml
secrets:
  - name: grafana-admin-secret
    namespace: monitoring
    type: Opaque
    scope: strict
    output_path: kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
    data:
      admin-user: admin
      admin-password: your-secure-password
```

```bash
make seal-secrets
```

## Related Documentation

- [Victoria Metrics Docs](https://docs.victoriametrics.com/)
- [Victoria Metrics Operator](https://docs.victoriametrics.com/operator/)
- [Grafana Docs](https://grafana.com/docs/)
- [MetricsQL](https://docs.victoriametrics.com/metricsql/)
