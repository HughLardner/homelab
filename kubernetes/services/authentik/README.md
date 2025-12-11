# Authentik SSO

Authentik is a self-hosted Identity Provider (IdP) providing single sign-on (SSO) for all homelab services.

## Features

- **OIDC/OAuth2 Provider**: Native SSO for Grafana, ArgoCD, and other OIDC-capable apps
- **SAML Support**: For legacy applications
- **Forward Authentication**: Protect any service via Traefik middleware
- **User Self-Service**: Password reset, 2FA enrollment, profile management
- **Customizable Flows**: Define authentication steps (password, 2FA, consent)

## Architecture

```
                                  ┌─────────────────────────┐
                                  │      Authentik          │
                                  │  ┌─────────────────┐    │
Browser ──> Traefik ──> Service   │  │  Server (UI/API)│    │
     │                     │      │  └────────┬────────┘    │
     │                     │      │           │             │
     │    ForwardAuth      │      │  ┌────────▼────────┐    │
     └─────────────────────┼──────┼─>│ Embedded Outpost│    │
                           │      │  │  (Proxy Auth)   │    │
                           │      │  └─────────────────┘    │
                           │      │                         │
                           │      │  ┌─────────┐ ┌───────┐  │
                           │      │  │PostgreSQL│ │ Redis │  │
                           │      │  └─────────┘ └───────┘  │
                           │      └─────────────────────────┘
                           │
              OIDC/SAML    │
           ◄───────────────┘
```

## Installation

### Prerequisites

- K3s cluster running
- Traefik ingress controller
- Cert-manager for TLS certificates
- Longhorn storage (or other PVC provider)

### Install via Ansible

```bash
# Ensure secrets are configured in Terraform
make authentik-install
```

### Manual Installation

```bash
# Add Helm repository
helm repo add authentik https://charts.goauthentik.io
helm repo update

# Install with values
helm upgrade --install authentik authentik/authentik \
  --namespace authentik \
  --create-namespace \
  --values values.yaml
```

## Initial Setup

1. **Access the setup wizard**:

   ```
   https://auth.silverseekers.org/if/flow/initial-setup/
   ```

2. **Create admin account**: Set username, email, and password

3. **Configure embedded outpost for Traefik**:
   - Go to **Applications > Outposts**
   - Click on **authentik Embedded Outpost**
   - Add applications you want to protect

## Integration Methods

### Method 1: Forward Authentication (Proxy)

Protect any service by adding the Authentik middleware to its IngressRoute:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-protected-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.silverseekers.org`)
      kind: Rule
      middlewares:
        - name: authentik
          namespace: authentik
      services:
        - name: my-app
          port: 80
  tls:
    secretName: my-app-tls
```

### Method 2: Native OIDC Integration

For applications that support OIDC (Grafana, ArgoCD, etc.):

1. **Create Provider in Authentik**:

   - Go to **Applications > Providers**
   - Click **Create** > **OAuth2/OpenID Provider**
   - Configure redirect URIs for your application

2. **Create Application in Authentik**:

   - Go to **Applications > Applications**
   - Click **Create**
   - Link to your provider

3. **Configure your application** with the OIDC details from Authentik

## OIDC Configuration Examples

### Grafana

In `grafana-values.yaml`:

```yaml
grafana.ini:
  server:
    root_url: https://grafana.silverseekers.org
  auth.generic_oauth:
    enabled: true
    name: Authentik
    allow_sign_up: true
    client_id: grafana
    client_secret: <from-authentik-provider>
    scopes: openid profile email
    auth_url: https://auth.silverseekers.org/application/o/authorize/
    token_url: https://auth.silverseekers.org/application/o/token/
    api_url: https://auth.silverseekers.org/application/o/userinfo/
    role_attribute_path: contains(groups[*], 'Grafana Admins') && 'Admin' || 'Viewer'
```

### ArgoCD

In `argocd-cm` ConfigMap:

```yaml
data:
  url: https://argocd.silverseekers.org
  oidc.config: |
    name: Authentik
    issuer: https://auth.silverseekers.org/application/o/argocd/
    clientID: argocd
    clientSecret: $oidc.authentik.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
```

## DNS Configuration

Add to UniFi Gateway (or your DNS server):

```
auth.silverseekers.org → 192.168.10.145
```

## Access Points

| URL                                                     | Description                    |
| ------------------------------------------------------- | ------------------------------ |
| `https://auth.silverseekers.org`                        | User login portal              |
| `https://auth.silverseekers.org/if/admin/`              | Admin interface                |
| `https://auth.silverseekers.org/if/flow/initial-setup/` | Initial setup (first run only) |

## Resource Usage

| Component  | CPU Request | Memory Request | Storage |
| ---------- | ----------- | -------------- | ------- |
| Server     | 100m        | 512Mi          | -       |
| Worker     | 100m        | 256Mi          | -       |
| PostgreSQL | 100m        | 256Mi          | 8Gi     |
| Redis      | 50m         | 64Mi           | 1Gi     |
| **Total**  | **350m**    | **~1.1Gi**     | **9Gi** |

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n authentik
```

### View logs

```bash
# Server logs
kubectl logs -n authentik -l app.kubernetes.io/component=server

# Worker logs
kubectl logs -n authentik -l app.kubernetes.io/component=worker
```

### Check certificate status

```bash
kubectl get certificate -n authentik
kubectl describe certificate authentik-server-tls -n authentik
```

### Test ForwardAuth middleware

```bash
# Should return 401 Unauthorized (redirects to login)
curl -I https://protected-app.silverseekers.org
```

## Security Considerations

- **Secret Key**: Must be at least 50 characters and cryptographically random
- **PostgreSQL Password**: Use a strong, unique password
- **HTTPS Only**: All endpoints should use TLS
- **2FA**: Enable for admin accounts at minimum

## Backup

Important data to backup:

1. PostgreSQL database
2. Secret key (stored in Kubernetes secret)
3. Provider configurations (exported via Admin UI or API)

## References

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Helm Chart](https://github.com/goauthentik/helm)
- [Traefik Integration](https://docs.goauthentik.io/docs/providers/proxy/server_traefik)
