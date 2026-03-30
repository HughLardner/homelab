# Open Thread Border Router (OTBR)

Bridges Home Assistant with the Thread radio on the SLZB-MR3U coordinator for Thread/Matter device integration.

## Architecture

- **Image:** bnutzer/otbr-tcp:latest (adds TCP RCP support vs official openthread/otbr)
- **Namespace:** home-automation
- **Wave:** 7 (after Home Assistant)
- **Network:** hostNetwork: true (required for mDNS)
- **Security:** NET_ADMIN, NET_RAW, SYS_MODULE capabilities (for iptables/network management)
- **Storage:** 1Gi Longhorn PVC for Thread network state

**Why bnutzer/otbr-tcp?** The official OpenThread OTBR image doesn't support TCP connections to network-based Thread radios. This custom image adds TCP support specifically for devices like the SLZB-MR3U that expose Thread over TCP.

## Configuration

Configured via `config/homelab.yaml`:
- `thread_rcp_url`: TCP endpoint to SLZB-MR3U Thread radio (192.168.40.185:6638)
- `mdns_interface`: Node network interface for mDNS advertisement (ens18)
- `rest_api_port`: 8081 (Home Assistant integration)
- `web_ui_port`: 80 (web UI)

## Access

- **Web UI:** https://otbr.silverseekers.org (protected by Authelia)
- **REST API:** http://otbr.home-automation.svc:8081 (cluster-internal)

## Home Assistant Integration

1. Navigate to Settings → Devices & Services
2. Thread integration should auto-discover OTBR via mDNS
3. Configure Thread integration pointing to OTBR REST API
4. Commission Thread devices via HA UI

## Verification

```bash
# Check pod status
kubectl get pods -n home-automation -l app.kubernetes.io/name=otbr

# Check logs
kubectl logs -n home-automation -l app.kubernetes.io/name=otbr

# Test REST API
kubectl exec -n home-automation $(kubectl get pod -n home-automation -l app.kubernetes.io/name=otbr -o name) -- curl localhost:8081/node/state

# Verify mDNS (from node)
ssh ubuntu@192.168.10.20 "avahi-browse -a | grep -i thread"
```

## Thread Network Management

Thread network credentials are stored in the PVC. To reset:
```bash
kubectl delete pvc otbr-data -n home-automation
# Redeploy via ArgoCD sync
```

## Troubleshooting

**OTBR not discovered by HA:**
- Verify hostNetwork: true is set
- Check mDNS interface matches node's primary interface
- Ensure Home Assistant Thread integration is enabled

**Cannot connect to Thread radio:**
- Verify thread_rcp_url in config/homelab.yaml
- Test TCP connectivity: `telnet 192.168.40.185 6638`
- Check SLZB-MR3U firmware and Thread radio enablement

**Pod fails to start (CrashLoopBackOff):**
- Check logs: `kubectl logs -n home-automation -l app.kubernetes.io/name=otbr`
- Verify SLZB-MR3U device is accessible from cluster network
- Ensure no port conflicts on host network
- If iptables errors: verify NET_ADMIN, NET_RAW, SYS_MODULE capabilities are set
- If "Permission denied" errors: check securityContext in deployment.yaml

**iptables/ip6tables permission errors:**
- Container requires NET_ADMIN, NET_RAW, and SYS_MODULE capabilities
- Verify securityContext is properly configured in deployment
- NAT64/DNS64/FIREWALL are disabled by default to avoid iptables/ip6tables complexity
- OTBR only needs basic Thread networking, not routing/NAT features
