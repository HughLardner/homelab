# Promtail - Log Collector

Promtail collects logs from all pods and sends them to Loki.

## Features

- **DaemonSet**: Runs on every node
- **Kubernetes Metadata**: Adds pod/namespace labels to logs
- **JSON Parsing**: Extracts structured log fields
- **Low Resource**: Minimal CPU/memory footprint

## How It Works

1. Promtail runs as a DaemonSet on every node
2. Mounts `/var/log/pods` to read container logs
3. Adds Kubernetes metadata (namespace, pod, container)
4. Pushes logs to Loki

## Viewing Logs

Use Grafana with the Loki datasource:

```logql
# All logs from namespace
{namespace="monitoring"}

# Filter by pod name
{pod=~"grafana.*"}

# Search for errors
{namespace="default"} |= "error"
```

## Configuration

| Setting | Value |
|---------|-------|
| Loki URL | http://loki.loki.svc:3100 |
| CPU Request | 50m |
| Memory Request | 64Mi |

