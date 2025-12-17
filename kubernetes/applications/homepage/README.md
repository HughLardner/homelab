# Homepage Dashboard

A modern, customizable dashboard for your homelab at `home.silverseekers.org`.

## Features

- **Kubernetes Auto-Discovery**: Automatically discovers services with Homepage annotations
- **Cluster Stats**: CPU, memory, and pod counts for Kubernetes cluster
- **Longhorn Integration**: Storage usage and health from Longhorn
- **Proxmox Integration**: VM and node statistics from Proxmox hypervisor
- **Weather Widget**: Current weather (requires OpenWeatherMap API key)
- **Authelia SSO**: Optional single sign-on protection

## Prerequisites

1. **Sealed Secrets controller** running in cluster
2. **Cert-manager** for TLS certificates
3. **Traefik** ingress controller
4. **Authelia** (optional, for SSO protection)

## Setup

### 1. Create Proxmox API Token

1. Log into Proxmox web UI (`https://192.168.10.100:8006`)
2. Navigate to **Datacenter** → **Permissions** → **API Tokens**
3. Click **Add** and configure:
   - User: `root@pam` or create a dedicated user like `homepage@pam`
   - Token ID: `homepage`
   - Privilege Separation: **Yes** (recommended)
4. Copy the generated token secret (shown only once!)
5. Set permissions for the token:
   - Navigate to **Datacenter** → **Permissions** → **Add** → **API Token Permission**
   - Path: `/`
   - API Token: `homepage@pam!homepage`
   - Role: `PVEAuditor` (or create custom role with `VM.Audit`, `Datastore.Audit`)

### 2. Get OpenWeatherMap API Key (Optional)

1. Sign up at [OpenWeatherMap](https://openweathermap.org/api)
2. Generate a free API key
3. Wait a few hours for the key to activate

### 3. Configure Secrets

Update `config/secrets.yml` with your credentials:

```yaml
secrets:
  - name: homepage-secrets
    namespace: homepage
    data:
      proxmox-token-id: "homepage@pam!homepage"
      proxmox-token-secret: "your-actual-token-secret"
      openweather-api-key: "your-openweather-key"  # Optional
```

### 4. Seal and Deploy

```bash
# Seal the secrets
make seal-secrets

# Commit and push to trigger ArgoCD sync
git add .
git commit -m "Add Homepage dashboard"
git push
```

## Configuration

### Enable/Disable Authentication

In `config/homelab.yaml`:

```yaml
services:
  homepage:
    domain: home.silverseekers.org
    auth_enabled: true  # Set to false for public access
```

### Add Weather Widget

In `config/homelab.yaml`:

```yaml
services:
  homepage:
    openweather_location: "New York"
    openweather_lat: "40.7128"
    openweather_lon: "-74.0060"
```

### Kubernetes Service Discovery

Add these annotations to any Service to auto-discover it on Homepage:

```yaml
metadata:
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: "My Service"
    gethomepage.dev/description: "Service description"
    gethomepage.dev/group: "Applications"
    gethomepage.dev/icon: "docker"
    gethomepage.dev/href: "https://myservice.silverseekers.org"
```

Available groups: `Infrastructure`, `Storage`, `Monitoring`, `Virtualization`, `Applications`

## Files

| File | Purpose |
|------|---------|
| `application.yaml` | ArgoCD Application definition |
| `Chart.yaml` | Helm chart metadata |
| `values.yaml` | Default Helm values |
| `homepage-values.yaml` | Official Homepage chart configuration |
| `templates/certificate.yaml` | TLS certificate |
| `templates/ingressroute.yaml` | Traefik ingress with optional auth |
| `templates/configmap-*.yaml` | Dashboard configuration |
| `secrets/` | Sealed secrets for API tokens |

## Troubleshooting

### Dashboard shows "Error loading data"

1. Check if secrets are properly sealed: `kubectl get secrets -n homepage`
2. Verify Proxmox API token permissions
3. Check Homepage pod logs: `kubectl logs -n homepage deploy/homepage`

### Longhorn widget not loading

Ensure Longhorn frontend service is accessible:
```bash
kubectl get svc -n longhorn-system longhorn-frontend
```

### Kubernetes stats not showing

Verify RBAC permissions:
```bash
kubectl get clusterrolebinding | grep homepage
```

## Resources

- [Homepage Documentation](https://gethomepage.dev)
- [Homepage Widgets](https://gethomepage.dev/widgets/)
- [Proxmox Widget](https://gethomepage.dev/widgets/services/proxmox/)
- [Kubernetes Widget](https://gethomepage.dev/widgets/info/kubernetes/)

