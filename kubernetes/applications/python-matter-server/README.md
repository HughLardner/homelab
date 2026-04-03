# Python Matter Server

Official Python implementation of the Matter protocol server for Home Assistant.

## Architecture

- **Image:** ghcr.io/matter-js/python-matter-server:8.1.2
- **Namespace:** home-automation
- **Wave:** 7 (after Home Assistant)
- **Network:** hostNetwork: true (required for Matter mDNS/commissioning)
- **Security:** NET_ADMIN, NET_RAW capabilities (for network access during commissioning)
- **Storage:** 1Gi Longhorn PVC for Matter fabric credentials and device data

Home Assistant only officially supports the OS-managed Matter app. This homelab
uses the upstream Matter server container instead, which is appropriate for a
containerized Home Assistant deployment but should be treated as an advanced,
operator-managed setup.

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
| **SLZB Device OTBR** | Thread Border Router (network layer) | 8080 (REST API) |
| **Matter Server** | Matter protocol handler (application layer) | 5580 (WebSocket) |

**Flow:** Matter device → Thread (via SLZB OTBR) → Matter Server → Home Assistant

## Configuration

Configured via `config/homelab.yaml`:

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

`primary_interface` should stay empty unless commissioning or mDNS binds to the
wrong NIC. Determine the correct override from the Matter server logs if you
need to pin it explicitly.

## Home Assistant Integration

### 1. Add Matter Integration

1. Navigate to **Settings → Devices & Services**
2. Click **Add Integration**
3. Search for **Matter**
4. When prompted to use an existing Matter server, provide:
   - **URL:** `ws://matter-server.home-automation.svc.cluster.local:5580/ws`
5. Finish the config flow in the UI

### 2. Commission Matter Devices

Once the Matter integration is added:

1. Click **Add Device** in the Matter integration
2. Follow the commissioning flow in Home Assistant
3. Scan the QR code or enter the pairing code from your Matter device
4. The device will join via Thread (through OTBR) or Wi-Fi

### 3. Verify Thread Connectivity

For Thread-based Matter devices:

```bash
# Check device-hosted OTBR REST endpoint is reachable
curl -sS http://192.168.10.185:8080/node/state

# Check Matter server logs
kubectl logs -n home-automation -l app.kubernetes.io/name=matter-server

# Verify Thread network status in Home Assistant
# Settings → Devices & Services → Thread
```

## Access

- **Service:** `matter-server.home-automation.svc:5580` (cluster-internal Service)
- **WebSocket URL:** `ws://matter-server.home-automation.svc.cluster.local:5580/ws`
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

If Home Assistant is already running, also verify the integration connects
cleanly:

```bash
kubectl logs -n home-automation deployment/matter-server | rg "Started|Listening|WebSocket|interface"
```

## Storage

Matter credentials and device data are stored in the PVC at `/data`. This includes:

- Matter fabric credentials (like your home network's "keys")
- Commissioned device information
- Device state and configuration

**Important:** Back up this PVC before cluster migrations or upgrades.

## Troubleshooting

### Matter integration cannot connect

- Verify the pod is running: `kubectl get pods -n home-automation`
- Check Matter server logs for errors
- Ensure Home Assistant is using the full URL: `ws://matter-server.home-automation.svc.cluster.local:5580/ws`

### Cannot Commission Matter Devices

- **Check hostNetwork:** Pod must use `hostNetwork: true` for mDNS
- **Check OTBR:** Thread devices require SLZB device-hosted OTBR to be reachable at `http://192.168.10.185:8080`
- **Check Thread integration:** Verify Thread integration is configured in HA
- **Network firewall:** Ensure no firewall rules blocking Matter traffic
- **Wrong NIC:** Set `services.python_matter_server.primary_interface` in `config/homelab.yaml` if the server binds to the wrong node interface

### Thread Devices Not Connecting

- Verify SLZB OTBR endpoint is up: `curl -sS http://192.168.10.185:8080/node/state`
- Verify Thread network is active in HA Thread integration
- Check device is within Thread network range

### Permission Errors

- Verify securityContext includes `NET_ADMIN` and `NET_RAW` capabilities
- Check pod security policies aren't blocking the capabilities

### Rollback

If a Matter server change breaks commissioning:

1. Revert the last repo change affecting `kubernetes/applications/python-matter-server`
2. Let ArgoCD resync the application
3. If fabric state is corrupted and you intentionally want a clean Matter fabric, delete `matter-server-data` only after confirming you are willing to re-pair devices

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
2. Update `services.python_matter_server.image_tag` in `config/homelab.yaml`
3. Commit and push (ArgoCD will sync automatically)

## Related Documentation

- [SLZB Thread setup](https://smlight.tech/support/manuals/books/slzb-06xmrxmrxuultima-series/page/thread-setup-network-and-usb-connection) - Device-hosted OTBR mode
- [Home Assistant](../home-assistant/README.md) - Main HA deployment
- [Matter Specification](https://csa-iot.org/all-solutions/matter/) - Official Matter protocol docs
