# Python Matter Server

Official Python implementation of the Matter protocol server for Home Assistant.

## Architecture

- **Image:** ghcr.io/home-assistant-libs/python-matter-server:6.7.0
- **Namespace:** home-automation
- **Wave:** 7 (after Home Assistant, alongside OTBR)
- **Network:** hostNetwork: true (required for Matter mDNS/commissioning)
- **Security:** NET_ADMIN, NET_RAW capabilities (for network access during commissioning)
- **Storage:** 1Gi Longhorn PVC for Matter fabric credentials and device data

## What It Does

Python Matter Server is the bridge between Home Assistant and Matter/Thread devices:

1. **Matter Protocol Handler** - Implements the Matter protocol stack
2. **Device Commissioning** - Pairs Matter devices to your network
3. **Thread Integration** - Works with OTBR for Thread-based Matter devices
4. **WebSocket API** - Exposes Matter devices to Home Assistant via WebSocket (port 5580)

## Integration with OTBR

Your setup has two complementary services:

| Service | Purpose | Port |
|---------|---------|------|
| **OTBR** | Thread Border Router (network layer) | 8081 (REST API) |
| **Matter Server** | Matter protocol handler (application layer) | 5580 (WebSocket) |

**Flow:** Matter device → Thread (via OTBR) → Matter Server → Home Assistant

## Configuration

Configured via `config/homelab.yaml`:

```yaml
services:
  python_matter_server:
    storage_size: 1Gi
    storage_class: longhorn
```

## Home Assistant Integration

### 1. Add Matter Integration

1. Navigate to **Settings → Devices & Services**
2. Click **Add Integration**
3. Search for **Matter (experimental)**
4. Configure:
   - **Host:** `matter-server.home-automation.svc.cluster.local` (or service ClusterIP)
   - **Port:** `5580`

### 2. Commission Matter Devices

Once the Matter integration is added:

1. Click **Add Device** in the Matter integration
2. Follow the commissioning flow in Home Assistant
3. Scan the QR code or enter the pairing code from your Matter device
4. The device will join via Thread (through OTBR) or Wi-Fi

### 3. Verify Thread Connectivity

For Thread-based Matter devices:

```bash
# Check OTBR is running and connected to Thread radio
kubectl logs -n home-automation -l app.kubernetes.io/name=otbr

# Check Matter server logs
kubectl logs -n home-automation -l app.kubernetes.io/name=matter-server

# Verify Thread network status in Home Assistant
# Settings → Devices & Services → Thread
```

## Access

- **Service:** `matter-server.home-automation.svc:5580` (cluster-internal WebSocket)
- **Host Network:** Also accessible via node IP on port 5580 (for debugging)

## Verification

```bash
# Check pod status
kubectl get pods -n home-automation -l app.kubernetes.io/name=matter-server

# Check logs
kubectl logs -n home-automation -l app.kubernetes.io/name=matter-server

# Test WebSocket connectivity (from within cluster)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v telnet://matter-server.home-automation.svc:5580

# Check storage
kubectl get pvc -n home-automation matter-server-data
```

## Storage

Matter credentials and device data are stored in the PVC at `/data`. This includes:

- Matter fabric credentials (like your home network's "keys")
- Commissioned device information
- Device state and configuration

**Important:** Back up this PVC before cluster migrations or upgrades.

## Troubleshooting

### Matter Integration Not Discovered

- Verify the pod is running: `kubectl get pods -n home-automation`
- Check Matter server logs for errors
- Ensure Home Assistant can reach the service: `matter-server.home-automation.svc:5580`

### Cannot Commission Matter Devices

- **Check hostNetwork:** Pod must use `hostNetwork: true` for mDNS
- **Check OTBR:** Thread devices require OTBR to be running and connected
- **Check Thread integration:** Verify Thread integration is configured in HA
- **Network firewall:** Ensure no firewall rules blocking Matter traffic

### Thread Devices Not Connecting

- Verify OTBR is running: `kubectl get pods -n home-automation -l app.kubernetes.io/name=otbr`
- Check OTBR connectivity to Thread radio (SLZB-MR3U at 192.168.40.185:6638)
- Verify Thread network is active in HA Thread integration
- Check device is within Thread network range

### Permission Errors

- Verify securityContext includes `NET_ADMIN` and `NET_RAW` capabilities
- Check pod security policies aren't blocking the capabilities

## Device Support

Matter devices supported by python-matter-server include:

- **Lights:** Bulbs, LED strips, smart switches
- **Sensors:** Temperature, humidity, motion, contact
- **Locks:** Smart locks and deadbolts
- **Plugs/Outlets:** Smart plugs and power strips
- **Thermostats:** HVAC controllers
- **Covers:** Blinds, shades, garage doors

Both **Thread** and **Wi-Fi** based Matter devices are supported.

## Updating

To update to a newer version:

1. Check releases: https://github.com/home-assistant-libs/python-matter-server/releases
2. Update `image.tag` in [values.yaml](values.yaml)
3. Commit and push (ArgoCD will sync automatically)

## Related Documentation

- [OTBR Setup](../otbr/README.md) - Thread Border Router configuration
- [Home Assistant](../home-assistant/README.md) - Main HA deployment
- [Matter Specification](https://csa-iot.org/all-solutions/matter/) - Official Matter protocol docs
