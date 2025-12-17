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

In Cloudflare Dashboard, add public hostnames:

| Subdomain | Domain            | Service                       |
| --------- | ----------------- | ----------------------------- |
| \*        | silverseekers.org | http://traefik.traefik.svc:80 |

Or configure specific routes:

| Subdomain | Service                       |
| --------- | ----------------------------- |
| grafana   | http://traefik.traefik.svc:80 |
| argocd    | http://traefik.traefik.svc:80 |
| longhorn  | http://traefik.traefik.svc:80 |

### 3. Add Token to Secrets

Add the tunnel token to `config/secrets.yml`:

```yaml
cloudflared:
  tunnel_token: "eyJhIjoiLi4uIn0="
```

Then seal the secret:

```bash
make seal-secrets
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────────────┬───────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Cloudflare Edge  │
                    │  (Zero Trust)     │
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
│            ┌───────────────┼───────────────┐                │
│            ▼               ▼               ▼                │
│       ┌─────────┐    ┌─────────┐    ┌─────────┐            │
│       │ Grafana │    │ ArgoCD  │    │Longhorn │            │
│       └─────────┘    └─────────┘    └─────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Cloudflare Access (Optional)

Add additional security with Cloudflare Access policies:

1. Go to **Zero Trust** > **Access** > **Applications**
2. Add an application for each service
3. Configure authentication (email, SSO, etc.)

This provides an additional layer before traffic reaches Authelia.
