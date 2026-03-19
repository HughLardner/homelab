# Cloudflared - Cloudflare Tunnel

Cloudflared provides secure external access to your homelab without requiring a static IP or opening firewall ports.

## Features

- **No Static IP Required**: Works behind CGNAT or dynamic IPs
- **No Port Forwarding**: No firewall configuration needed
- **Zero Trust Security**: Cloudflare Access policies
- **DDoS Protection**: Cloudflare's network protection

## Prerequisites

### 1. Create Cloudflare Tunnel

1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to **Zero Trust** > **Networks** > **Tunnels**
3. Click **Create a tunnel**
4. Name: `homelab-tunnel`
5. Copy the tunnel token

### 2. Configure Tunnel Routes

In Cloudflare Dashboard, configure **only** this public hostname:

| Subdomain | Domain            | Service                       |
| --------- | ----------------- | ----------------------------- |
| fallandrise | silverseekers.org | http://traefik.traefik.svc:80 |

> **Note:** Only `fallandrise.silverseekers.org` is intentionally exposed. All other services are internal-only.
> The catch-all / default route should be set to `http_status:404` to block anything not explicitly listed.

Previously allowed wildcard routes (now removed):
- ~~`*` → `http://traefik.traefik.svc:80`~~ (removed — exposed all services publicly)

### 3. Add Token to Secrets

Add the tunnel token to `config/secrets.yml`:

```yaml
cloudflared:
  tunnel_token: "<set-in-secrets-file>="
```

Then seal the secret:

```bash
make seal-secrets
```

## Architecture

Only `fallandrise.silverseekers.org` is routed through the tunnel. All other services are internal-only.

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
│          (only fallandrise.silverseekers.org)                │
└─────────────────────────────┬───────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Cloudflare Edge  │
                    │  (Zero Trust)     │
                    │  404 catch-all    │
                    └─────────┬─────────┘
                              │ Encrypted Tunnel
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                     Homelab Cluster                          │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    cloudflared pod                       ││
│  │               (outbound tunnel connector)                ││
│  └─────────────────────────┬───────────────────────────────┘│
│                            │                                 │
│                   ┌────────▼────────┐                       │
│                   │     Traefik     │                       │
│                   │  (Ingress)      │                       │
│                   └────────┬────────┘                       │
│                            │                                 │
│                            ▼                                 │
│                    ┌──────────────┐                         │
│                    │    Quartz    │  (fallandrise — public)  │
│                    │ (read-only)  │                         │
│                    └──────────────┘                         │
│                                                             │
│  All other services (Grafana, ArgoCD, Longhorn, etc.)       │
│  are internal-only — no public DNS, no tunnel route.        │
└─────────────────────────────────────────────────────────────┘
```

## Cloudflare Dashboard Configuration

To configure the tunnel routes manually in the dashboard:

1. Go to **Zero Trust** > **Networks** > **Tunnels** > `homelab-tunnel`
2. Click **Edit** > **Public Hostnames**
3. Ensure **only** this entry exists:
   - Subdomain: `fallandrise` / Domain: `silverseekers.org`
   - Service type: `HTTP` / URL: `traefik.traefik.svc:80`
4. Set the **catch-all / default route** to `http_status:404`
5. Remove any wildcard (`*`) or other hostname entries

## Cloudflare Access (Optional but Recommended)

If you later want to gate `fallandrise` behind email verification or SSO:

1. Go to **Zero Trust** > **Access** > **Applications**
2. Add application for `fallandrise.silverseekers.org`
3. Configure policy (e.g. allow list of emails, or make fully public)

For a fully public read-only site, no Access policy is needed.
