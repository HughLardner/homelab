# Monitoring Stack (Prometheus + Grafana)

Complete monitoring solution using the kube-prometheus-stack for Kubernetes observability.

## Overview

This deployment includes:
- **Prometheus** - Metrics collection, storage, and alerting
- **Grafana** - Metrics visualization and dashboarding
- **Alertmanager** - Alert routing and management
- **Node Exporter** - Host-level metrics
- **Kube State Metrics** - Kubernetes object metrics
- **Prometheus Operator** - Manages Prometheus instances via CRDs

## Deployment

### GitOps Deployment (Recommended)

This monitoring stack is deployed via **ArgoCD** for continuous GitOps delivery.

#### How It Works

1. The monitoring ArgoCD Application is defined in [kubernetes/applications/monitoring/application.yaml](../../applications/monitoring/application.yaml)
2. ArgoCD watches this repo and automatically syncs changes
3. Configuration is managed in [values.yaml](./values.yaml) and [ingressroute.yaml](./ingressroute.yaml)

#### Deployment Options

**Option 1: Via Root App (Recommended)**

The monitoring Application is automatically deployed by the root-app:

```bash
# Deploy the App-of-Apps (if not already done)
kubectl apply -f kubernetes/applications/root-app.yaml

# Verify monitoring application was created
argocd app list | grep monitoring
kubectl get application monitoring -n argocd

# Check sync status
argocd app get monitoring
```

**Option 2: Deploy Directly**

```bash
# Deploy just the monitoring Application
kubectl apply -f kubernetes/applications/monitoring/application.yaml

# Sync the application
argocd app sync monitoring

# Watch deployment
argocd app get monitoring --watch
```

#### Making Changes

1. Edit configuration files in this directory:
   ```bash
   vim kubernetes/services/monitoring/values.yaml
   ```

2. Commit and push:
   ```bash
   git add kubernetes/services/monitoring/values.yaml
   git commit -m "Update monitoring retention to 30d"
   git push
   ```

3. ArgoCD automatically syncs (if automated sync enabled):
   ```bash
   # Or manually sync
   argocd app sync monitoring
   ```

### Legacy Ansible Deployment

The Ansible playbook is kept for bootstrap or non-GitOps scenarios:

```bash
# Install monitoring stack via Ansible
make monitoring-install

# Check status
make monitoring-status

# Open Grafana
make grafana-ui
```

**Note:** When using GitOps, prefer ArgoCD over Ansible for consistency.

## Accessing Grafana

After installation, access Grafana at:
- URL: `https://grafana.silverseekers.org`
- Username: `admin`
- Password: Configured via Sealed Secrets (see [Secrets Management](#secrets-management))

## Pre-loaded Dashboards

The following dashboards are automatically installed:

| Dashboard | Description | Grafana ID |
|-----------|-------------|------------|
| Kubernetes Cluster | Overall cluster metrics | 7249 |
| Node Exporter Full | Detailed node metrics | 1860 |
| Persistent Volumes | Storage metrics | 13646 |

Access dashboards: **Home → Dashboards**

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Namespace                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │  Prometheus  │───→│  Grafana     │    │  Alertmanager   │  │
│  │  (Storage)   │    │  (Visualize) │    │  (Alerts)       │  │
│  └──────┬───────┘    └──────────────┘    └──────────────────┘  │
│         │                     ▲                                 │
│         │ scrapes             │ queries                         │
│         ▼                     │                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Service Monitors (CRDs)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
        │                │                │                │
        ▼                ▼                ▼                ▼
  Node Exporter    Kubelet Metrics   API Server     Your Apps
  (host metrics)   (container)       (K8s metrics)  (custom)
```

## Configuration

### Secrets Management

Grafana credentials are managed via **Sealed Secrets**:

```bash
# 1. Create secrets.yml with Grafana credentials
cp ../../../secrets.example.yml ../../../secrets.yml
vim ../../../secrets.yml

# 2. Add Grafana admin secret:
secrets:
  - name: grafana-admin-secret
    namespace: monitoring
    type: Opaque
    scope: strict
    output_path: kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
    data:
      admin-user: admin
      admin-password: your-secure-password

# 3. Encrypt and commit
make seal-secrets
```

See [secrets/README.md](./secrets/README.md) and [SECRETS.md](../../../SECRETS.md) for details.

### Terraform Variables

```hcl
# clusters.tf
grafana_domain = "grafana.silverseekers.org"
```

### Helm Values

Configuration is managed in [values.yaml](./values.yaml):

| Setting | Default | Description |
|---------|---------|-------------|
| `monitoring_namespace` | `monitoring` | Kubernetes namespace |
| `monitoring_storage_class` | `longhorn` | StorageClass for PVCs |
| `prometheus_storage_size` | `10Gi` | Prometheus data volume |
| `prometheus_retention` | `15d` | Metrics retention period |
| `grafana_storage_size` | `5Gi` | Grafana data volume |
| `alertmanager_storage_size` | `2Gi` | Alertmanager volume |

## Components

### Prometheus

**Endpoints:**
- Internal: `http://kube-prometheus-prometheus:9090`
- Port-forward: `kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090`

**Query Examples:**
```promql
# CPU usage by pod
rate(container_cpu_usage_seconds_total[5m])

# Memory usage by namespace
sum(container_memory_usage_bytes) by (namespace)

# Pod restart count
kube_pod_container_status_restarts_total
```

### Grafana

**Features:**
- Pre-configured Prometheus datasource
- Auto-loaded dashboards
- TLS via Traefik IngressRoute
- Persistent storage for dashboards

**Creating Custom Dashboards:**
1. Log in to Grafana
2. Click "+ → Dashboard"
3. Add panels with PromQL queries
4. Save dashboard

### Alertmanager

**Default Alerts Included:**
- Node down
- High CPU usage
- High memory usage
- Pod crash looping
- PVC almost full
- Certificate expiring soon

**Viewing Alerts:**
```bash
# Port-forward Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-alertmanager 9093:9093

# Open http://localhost:9093
```

## Service Monitors

Service Monitors are CRDs that tell Prometheus what to scrape.

### Create Service Monitor for Your App

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### Expose Metrics from Your App

```go
// Example: Expose metrics endpoint
import "github.com/prometheus/client_golang/prometheus/promhttp"

http.Handle("/metrics", promhttp.Handler())
```

## Storage

All components use Longhorn for persistent storage:

| Component | PVC Size | Purpose |
|-----------|----------|---------|
| Prometheus | 10Gi | Metrics data |
| Grafana | 5Gi | Dashboards & config |
| Alertmanager | 2Gi | Alert state |

**View PVCs:**
```bash
kubectl get pvc -n monitoring
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
```

### View Prometheus Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### View Grafana Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Prometheus Not Scraping Targets

1. Check Service Monitor exists:
```bash
kubectl get servicemonitor -A
```

2. Check Prometheus targets:
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
```

3. Verify service has correct labels and port name

### Grafana Dashboard Not Loading

1. Check datasource connection:
   - Grafana → Configuration → Data Sources → Prometheus
   - Click "Test" button

2. Verify Prometheus is running:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
```

### High Memory Usage

Prometheus memory usage grows with:
- Number of metrics
- Retention period
- Scrape frequency

**Reduce retention:**
```yaml
# values.yaml
prometheus:
  prometheusSpec:
    retention: 7d  # Reduce from 15d
```

## Metrics Endpoints

Pre-configured scrape targets:

| Target | Metrics |
|--------|---------|
| Kubelet | Container CPU, memory, network |
| API Server | Request rates, latency |
| Node Exporter | CPU, memory, disk, network |
| Kube State Metrics | Pod status, deployment status |
| CoreDNS | DNS query rates |

## Advanced Configuration

### Add External Alertmanager

```yaml
# values.yaml
alertmanager:
  config:
    route:
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: '<webhook-url>'
            channel: '#alerts'
```

### Custom Recording Rules

```yaml
# values.yaml
prometheus:
  prometheusSpec:
    additionalPrometheusRules:
      - name: custom-rules
        groups:
          - name: custom
            rules:
              - record: job:node_cpu:avg
                expr: avg by(job)(rate(node_cpu_seconds_total[5m]))
```

## Related Documentation

- [Prometheus Docs](https://prometheus.io/docs/)
- [Grafana Docs](https://grafana.com/docs/)
- [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
