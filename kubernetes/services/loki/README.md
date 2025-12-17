# Loki - Centralized Log Aggregation

Loki is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

## Features

- **SingleBinary Mode**: Simplified deployment for homelab
- **14-Day Retention**: Automatic log cleanup
- **Grafana Integration**: Query logs directly from Grafana
- **Promtail Collection**: Logs collected from all pods

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐       │
│  │   Pod A     │    │   Pod B     │    │   Pod C     │       │
│  │  (logs)     │    │  (logs)     │    │  (logs)     │       │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘       │
│         │                  │                  │               │
│         └─────────────┬────┴────┬─────────────┘               │
│                       │         │                             │
│                  ┌────▼─────────▼────┐                        │
│                  │     Promtail      │ (DaemonSet)            │
│                  │  (log collector)  │                        │
│                  └─────────┬─────────┘                        │
│                            │                                  │
│                       ┌────▼────┐                             │
│                       │  Loki   │                             │
│                       │(storage)│                             │
│                       └────┬────┘                             │
│                            │                                  │
│                       ┌────▼────┐                             │
│                       │ Grafana │                             │
│                       │ (query) │                             │
│                       └─────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

## Grafana Integration

Loki is automatically configured as a datasource in Grafana. Use LogQL to query logs:

### Example Queries

```logql
# All logs from a namespace
{namespace="monitoring"}

# Errors in the last hour
{namespace="monitoring"} |= "error"

# Logs from specific pod
{pod=~"grafana.*"}

# Parse JSON logs
{namespace="authelia"} | json | level="error"
```

## Configuration

| Setting | Value |
|---------|-------|
| Retention | 14 days |
| Storage | 10Gi (Longhorn) |
| Replicas | 1 (SingleBinary) |
| Auth | Disabled (internal) |

