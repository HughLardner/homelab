# Syslog Receiver

Dedicated UDP syslog intake for LAN devices that need to send `RFC3164`/BSD-style
syslog into the homelab logging stack.

## Purpose

This service gives devices such as the `SLZB-MR3U` a stable LAN endpoint for
`UDP` syslog. It accepts the packets, adds stable labels, and forwards the logs
to Loki so they are searchable in Grafana.

## Architecture

```text
SLZB-MR3U --UDP RFC3164--> MetalLB LoadBalancer IP --UDP--> Vector --> Loki --> Grafana
```

## Configuration

Configured via `config/homelab.yaml`:

```yaml
services:
  syslog_receiver:
    enabled: true
    load_balancer_ip: "192.168.10.153"
    service_port: 514
    target_port: 5514
    default_labels:
      job: slzb
      device: slzb-mr3u
```

### Port model

- `service_port`: external UDP port exposed on the MetalLB IP
- `target_port`: unprivileged UDP port used inside the container

The default configuration exposes `UDP 514` externally while the container
listens on `UDP 5514`.

## SLZB Device Settings

Set the SLZB syslog client to:

- **Format:** BSD / RFC3164
- **Protocol:** UDP
- **Host:** `192.168.10.153`
- **Port:** `514`

## Querying in Grafana

Use the existing Loki datasource in Grafana:

```logql
{job="slzb"}
```

```logql
{job="slzb", device="slzb-mr3u"} |= "error"
```

## Verification

```bash
# Confirm the service has the expected MetalLB IP
kubectl get svc -n loki syslog-receiver

# Check the receiver pod
kubectl get pods -n loki -l app.kubernetes.io/name=syslog-receiver

# Inspect receiver logs
kubectl logs -n loki deployment/syslog-receiver

# Send a test RFC3164-style packet from another LAN host
logger -n 192.168.10.153 -P 514 -d -t slzb-test "syslog receiver smoke test"
```

Then query Grafana Loki with `{job="slzb"}` and confirm the test line appears.

