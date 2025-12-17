# External-DNS - Automatic DNS Management

External-DNS automatically manages Cloudflare DNS records based on Kubernetes Ingress/Service annotations.

## Features

- **Automatic Records**: Creates DNS records from Ingress resources
- **Sync Policy**: Removes orphaned records when Ingress is deleted
- **Cloudflare API**: Uses API token for secure access

## Prerequisites

### 1. Create Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use **Edit zone DNS** template
4. Permissions:
   - Zone: DNS: Edit
   - Zone: Zone: Read
5. Zone Resources: Include specific zone: `silverseekers.org`
6. Create and copy the token

### 2. Add Token to Secrets

Add the API token to `config/secrets.yml`:

```yaml
cloudflare:
  api_token: "<your-api-token>"
```

Then seal the secret:

```bash
make seal-secrets
```

## Usage

DNS records are automatically created from Ingress resources.

### IngressRoute Annotation

For Traefik IngressRoutes, the hostname is extracted from the route match:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  annotations:
    external-dns.alpha.kubernetes.io/target: 192.168.10.145
spec:
  routes:
    - match: Host(`myapp.silverseekers.org`)
```

### Service Annotation (LoadBalancer)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: myservice.silverseekers.org
spec:
  type: LoadBalancer
```

## Managed Records

External-DNS will manage A/CNAME records for:

| Service | Hostname |
|---------|----------|
| Grafana | grafana.silverseekers.org |
| ArgoCD | argocd.silverseekers.org |
| Traefik | traefik.silverseekers.org |
| Authelia | auth.silverseekers.org |
| Longhorn | longhorn.silverseekers.org |

## Troubleshooting

```bash
# Check External-DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# List managed records (from logs)
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep "Desired"
```

