# Home Assistant

Open source home automation platform running on Kubernetes with Authelia SSO integration.

## Overview

This deployment uses the [pajikos/home-assistant-helm-chart](https://github.com/pajikos/home-assistant-helm-chart) as a Helm dependency, which provides:

- StatefulSet for persistent pod identity
- Automatic configuration management
- Persistent storage via Longhorn
- Health probes and resource management

Custom templates provide:

- Traefik IngressRoute for HTTPS access
- cert-manager Certificate for TLS
- **Automatic HACS installation** via post-install job
- **Automatic owner creation** - no manual onboarding required!

Both automation features are adapted from [small-hack/home-assistant-chart](https://github.com/small-hack/home-assistant-chart).

## Access

- **URL**: https://home-assistant.silverseekers.org
- **Authentication**: Authelia SSO via OIDC

## Thread / OTBR Endpoint

OTBR is hosted on the SLZB-MR3U device (not in-cluster). Configure Home Assistant integrations to use:

- **OTBR REST URL:** `http://192.168.40.185:8080`
- **Matter Server URL:** `ws://matter-server.home-automation.svc.cluster.local:5580/ws`

### VLAN and firewall prerequisites (critical)

In this homelab, Home Assistant and SLZB are on different VLANs:
- HA path: `192.168.10.0/24` (Homelab VLAN)
- SLZB OTBR: `192.168.40.185` on `192.168.40.0/24` (IoT VLAN)

Before troubleshooting HA integrations, confirm network policy allows:
- HA -> SLZB OTBR on TCP `8080` (required)
- Optional HA -> SLZB OTBR on TCP `80` (diagnostics/UI)

For mobile Matter commissioning:
- Avoid guest/client-isolated SSIDs during pairing.
- If phone is on a different VLAN, ensure cross-VLAN mDNS reflection is enabled.
- Ensure IPv6 is enabled for VLANs participating in Thread/Matter onboarding.
- In this homelab, a phone on `Default` is still not the same onboarding LAN as
  HA on `Homelab`; for the initial `Sync Thread Credentials` and Matter pairing
  flow, use the trusted HA-side LAN/SSID first.

Recommended checks after any OTBR or firmware change:

```bash
curl -sS http://192.168.40.185:8080/node/state
curl -sS http://192.168.40.185:8080/node/ba-id
kubectl -n home-assistant exec home-assistant-0 -- \
  curl -sS http://192.168.40.185:8080/node/state
```

## Matter Server

Because this Home Assistant deployment runs in a container rather than Home
Assistant OS, it cannot use the Supervisor Matter add-on. Instead, this repo
deploys the standalone Python Matter Server in Kubernetes at
`kubernetes/applications/python-matter-server`.

The Matter integration itself is still configured in the Home Assistant UI:

1. Go to **Settings → Devices & Services**
2. Add the **Matter** integration
3. Choose the existing/external Matter server option
4. Enter `ws://matter-server.home-automation.svc.cluster.local:5580/ws`

Keep the HA Thread integration pointed at the SLZB OTBR endpoint above for
Thread-backed Matter devices.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Traefik Ingress                       │
│              home-assistant.silverseekers.org            │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Home Assistant Service                      │
│                   (ClusterIP)                            │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│            Home Assistant StatefulSet                    │
│         ghcr.io/home-assistant/home-assistant            │
│                                                          │
│    ┌─────────────────────────────────────────────┐      │
│    │         hass-oidc-auth integration          │      │
│    │              (HACS component)               │      │
│    └─────────────────┬───────────────────────────┘      │
└──────────────────────┼──────────────────────────────────┘
                       │ OIDC
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Authelia SSO                           │
│              auth.silverseekers.org                      │
└─────────────────────────────────────────────────────────┘
```

## Automatic Deployment

Both **HACS** and the **initial owner user** are created automatically via post-install jobs!

### What Happens Automatically

1. **Owner Creation** (`create-owner` job): Creates the initial admin user
   - Username: `admin` (configurable in secrets)
   - Password: Stored in `home-assistant-owner-credentials` secret
   - Skips the manual onboarding wizard entirely

2. **HACS Installation** (`setup-hacs` job): Installs HACS files
   - Downloads HACS to `/config/custom_components/hacs`
   - You still need to complete HACS setup in the UI (see below)

### Default Credentials

The initial admin credentials are read from `config/secrets.yml`:

```yaml
- name: home-assistant-owner-credentials
  data:
    ADMIN_NAME: "<set-in-secrets-file>"
    ADMIN_USERNAME: "<set-in-secrets-file>"
    ADMIN_PASSWORD: "<set-in-secrets-file>"
    ADMIN_LANGUAGE: "en"
```

**⚠️ Never commit real credentials to Git. Change the password after first login.**

## Post-Deploy: Complete HACS Setup in UI

HACS files are automatically installed, but you need to complete the GitHub integration:

1. Access https://home-assistant.silverseekers.org
2. Login with the auto-created credentials (or change password first)
3. Restart Home Assistant: **Settings → System → Restart**
4. Go to **Settings → Devices & Services → Add Integration**
5. Search for "HACS" and add it
6. Complete GitHub authentication (requires a GitHub account)

> **Note**: If jobs failed, check their status:
>
> ```bash
> kubectl get jobs -n home-assistant
> kubectl logs -n home-assistant job/home-assistant-create-owner
> kubectl logs -n home-assistant job/home-assistant-setup-hacs
> ```

### Step 3: Install OIDC Authentication

1. In HACS, go to **Integrations**
2. Click **+ Explore & Download Repositories**
3. Search for "OIDC Authentication" or "hass-oidc-auth"
4. Download and install the integration
5. Restart Home Assistant

### Step 4: Configure OIDC

Add to your `configuration.yaml` (via code-server or kubectl exec):

```yaml
auth_oidc:
  client_id: home-assistant
  client_secret: !env_var OIDC_CLIENT_SECRET
  discovery_url: https://auth.silverseekers.org/.well-known/openid-configuration
  display_name: "Authelia"
```

Or configure via UI after installing the integration.

### Step 5: Restart and Test

```bash
kubectl rollout restart statefulset -n home-assistant home-assistant-homeassistant
```

Access https://home-assistant.silverseekers.org - you should see "Login with Authelia" option.

## Configuration

### Chart Dependencies

The `Chart.yaml` declares the pajikos helm chart as a dependency:

```yaml
dependencies:
  - name: home-assistant
    version: "0.3.35"
    repository: https://pajikos.github.io/home-assistant-helm-chart/
    alias: homeassistant
```

### Key Values

| Value                                    | Description                                      | Default         |
| ---------------------------------------- | ------------------------------------------------ | --------------- |
| `auth_enabled`                           | Enable Authelia forward auth (disabled for OIDC) | `false`         |
| `setupHacs.enabled`                      | Auto-install HACS via post-install job           | `true`          |
| `homeassistant.persistence.size`         | Storage size                                     | `10Gi`          |
| `homeassistant.persistence.storageClass` | Storage class                                    | `longhorn`      |
| `homeassistant.resources`                | CPU/memory limits                                | See values.yaml |

### Home Assistant Configuration

The chart manages `configuration.yaml` via the `homeassistant.configuration` values:

```yaml
homeassistant:
  configuration:
    enabled: true
    trusted_proxies:
      - 10.42.0.0/16 # K3s pod CIDR
```

## Secrets

The OIDC client credentials are stored in `home-assistant-oidc-secret`:

| Key             | Description                     |
| --------------- | ------------------------------- |
| `client-id`     | OIDC client ID (home-assistant) |
| `client-secret` | OIDC client secret              |

To regenerate secrets:

```bash
# Generate new secret
openssl rand -hex 32

# Update config/secrets.yml with new value
# Update kubernetes/services/authelia/authelia-values.yaml with matching value
# Reseal secrets
make seal-secrets
```

## Upgrading

To update the Home Assistant version:

1. Update `homeassistant.image.tag` in `values.yaml`
2. Commit and push - ArgoCD will sync automatically

To update the Helm chart version:

1. Update the `version` in `Chart.yaml` dependencies
2. Run `helm dependency update` locally to test
3. Commit and push

### Auto-updates with Renovate

Home Assistant image updates are also tracked automatically via the repository
`renovate.json` config. Renovate watches
`kubernetes/applications/home-assistant/values.yaml` and opens a PR when a new
stable `ghcr.io/home-assistant/home-assistant` tag is published.

Current policy:

- Match only `homeassistant.image.tag`
- Track `ghcr.io/home-assistant/home-assistant`
- Allow stable tags only in `x.y.z` format
- Exclude floating aliases and pre-releases such as `latest`, `beta`, `rc`, and `dev`
- Require manual merge (`automerge: false`)
- Run on the weekly schedule defined in `renovate.json`

Merge and deploy flow:

1. Renovate opens a PR with only the Home Assistant image tag change
2. Review the upstream release and merge the PR
3. ArgoCD detects the Git change and syncs the updated StatefulSet
4. Verify the deployed image tag after sync

Rollback:

1. Revert the Renovate PR, or manually pin the previous known-good tag in `values.yaml`
2. Commit and push the rollback change
3. Re-sync ArgoCD if needed

Useful verification command:

```bash
kubectl -n home-assistant get sts home-assistant-homeassistant \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n home-assistant
kubectl logs -n home-assistant -l app.kubernetes.io/name=home-assistant
```

### Check HACS setup job

```bash
# Check job status
kubectl get jobs -n home-assistant

# View job logs
kubectl logs -n home-assistant job/home-assistant-setup-hacs

# If job failed, delete and let ArgoCD recreate
kubectl delete job -n home-assistant home-assistant-setup-hacs
```

### Check OIDC configuration

```bash
# Verify Authelia OIDC discovery
curl -s https://auth.silverseekers.org/.well-known/openid-configuration | jq

# Check if HA has the OIDC secret mounted
kubectl exec -n home-assistant -it sts/home-assistant-homeassistant -- env | grep OIDC
```

### Access Home Assistant shell

```bash
kubectl exec -n home-assistant -it sts/home-assistant-homeassistant -- /bin/bash
```

### Manual HACS Installation

If the automatic job fails, install HACS manually:

```bash
kubectl exec -n home-assistant -it sts/home-assistant-homeassistant -- /bin/bash -c \
  "cd /config && wget -O - https://get.hacs.xyz | bash -"
```

### OIDC Login Not Working

1. Verify the integration is installed: Check **Settings → Devices & Services**
2. Check logs for OIDC errors: **Settings → System → Logs**
3. Verify redirect URI matches: `https://home-assistant.silverseekers.org/auth/oidc/callback`
4. Fall back to local login if needed (use the account created during onboarding)

### Reset Authentication

If locked out, you can reset auth by editing the config:

```bash
kubectl exec -n home-assistant -it sts/home-assistant-homeassistant -- \
  rm /config/.storage/auth_provider.homeassistant
kubectl rollout restart statefulset -n home-assistant home-assistant-homeassistant
```
