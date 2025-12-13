# Authelia SSO

Lightweight Single Sign-On (SSO) solution for the homelab. Replaces Authentik with ~95% memory savings.

## Overview

- **Memory Usage**: ~35MB (vs Authentik's ~900MB)
- **Storage**: SQLite (file-based)
- **Sessions**: Redis
- **Authentication**: File-based user database
- **OIDC**: Grafana, ArgoCD
- **Forward Auth**: Traefik dashboard, Longhorn UI, other services

## Components

| Component       | Purpose                          |
| --------------- | -------------------------------- |
| Authelia Server | SSO, OIDC provider, forward auth |
| Redis           | Session storage                  |
| SQLite          | User data, OIDC tokens           |

## Access

- **URL**: https://auth.silverseekers.org
- **Admin User**: admin
- **Password**: (from secrets.yml)

## OIDC Clients

| Client ID | Application | Redirect URI                                          |
| --------- | ----------- | ----------------------------------------------------- |
| grafana   | Grafana     | https://grafana.silverseekers.org/login/generic_oauth |
| argocd    | ArgoCD      | https://argocd.silverseekers.org/auth/callback        |

## User Groups

| Group           | Access                      |
| --------------- | --------------------------- |
| admins          | Full access to all services |
| grafana_admins  | Grafana Admin role          |
| grafana_editors | Grafana Editor role         |
| grafana_viewers | Grafana Viewer role         |
| argocd_admins   | ArgoCD admin access         |

## ForwardAuth Middleware

To protect a service with Authelia, add this middleware to the IngressRoute:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-service
  namespace: my-namespace
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`my-service.silverseekers.org`)
      kind: Rule
      middlewares:
        - name: authelia-forward-auth
          namespace: authelia
      services:
        - name: my-service
          port: 80
  tls:
    secretName: my-service-tls
```

## Deployment

```bash
# Apply secrets first
make authelia-secrets

# Deploy Authelia
make authelia-install

# Check status
make authelia-status
```

## Generating Password Hashes

For new users or password changes:

```bash
# Using Docker
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'your-password'

# Output format: $argon2id$v=19$m=65536,t=3,p=4$...
```

## OIDC Client Secret Hashes

For OIDC client secrets:

```bash
# Generate a random secret
openssl rand -hex 32

# Hash it for Authelia config
docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --password 'your-client-secret'
```

## Troubleshooting

### Check logs

```bash
kubectl logs -n authelia deployment/authelia -f
```

### Verify OIDC discovery

```bash
curl -s https://auth.silverseekers.org/.well-known/openid-configuration | jq
```

### Test forward auth

```bash
curl -I -H "X-Forwarded-Proto: https" -H "X-Forwarded-Host: grafana.silverseekers.org" http://authelia.authelia.svc.cluster.local:9091/api/authz/forward-auth
```
