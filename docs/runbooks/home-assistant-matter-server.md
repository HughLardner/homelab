# Home Assistant Matter Server

Runbook for operating the standalone Matter server used by the containerized
Home Assistant deployment in this homelab.

## Why This Exists

Home Assistant runs here as a container on Kubernetes, so the Supervisor Matter
add-on is not available. The cluster instead runs the upstream Python Matter
Server as a separate workload and Home Assistant connects to it over WebSocket.

## GitOps Source

- Chart: `kubernetes/applications/python-matter-server`
- ArgoCD app: `kubernetes/applications/python-matter-server/application.yaml`
- Shared config: `config/homelab.yaml`

## Required Settings

`config/homelab.yaml`:

```yaml
services:
  python_matter_server:
    image_tag: "8.1.2"
    log_level: info
    host_network: true
    primary_interface: ""
    storage_size: 1Gi
    storage_class: longhorn
```

Leave `primary_interface` empty unless the Matter server binds to the wrong NIC
for commissioning or mDNS. If you need to set it, derive the interface name
from the Matter server startup logs first.

## Home Assistant Connection

Configure the Home Assistant Matter integration in the UI with:

- URL: `ws://matter-server.home-automation.svc.cluster.local:5580/ws`

For Thread-backed Matter devices, keep the Thread integration pointed at the
device-hosted OTBR endpoint:

- OTBR REST URL: `http://192.168.40.185:8080`

## Verification

```bash
kubectl get application -n argocd python-matter-server
kubectl get pods -n home-automation -l app.kubernetes.io/name=matter-server
kubectl logs -n home-automation deployment/matter-server
kubectl get svc,pvc -n home-automation | rg "matter-server|matter-server-data"
kubectl run -i --rm curl --image=curlimages/curl --restart=Never -- \
  curl -sS telnet://matter-server.home-automation.svc:5580
curl -sS http://192.168.40.185:8080/node/state
```

Success looks like:

- ArgoCD app is `Synced` and `Healthy`
- Matter server pod is `Running` and not crash-looping
- `matter-server-data` PVC is `Bound`
- Home Assistant connects to the Matter server URL without retry loops
- A test Matter device can be commissioned and controlled

## Common Failures

### Home Assistant cannot connect

- Confirm the UI is using the full WebSocket URL, not only host/port
- Check the Matter server pod logs
- Verify the service resolves from the cluster DNS name

### Commissioning fails or mDNS is unreliable

- Confirm `host_network` is `true`
- Set `primary_interface` if the wrong node NIC is selected
- Verify IPv6 and local LAN multicast work on the node

### Thread devices do not join

- Confirm the SLZB OTBR endpoint is reachable at `http://192.168.40.185:8080`
- Verify the Home Assistant Thread integration is healthy

## Rollback

1. Revert the last change affecting `python-matter-server`
2. Let ArgoCD resync the application
3. If the application version is the issue, roll back `services.python_matter_server.image_tag`
4. Delete `matter-server-data` only if you intentionally want to discard Matter fabric state and re-pair devices
