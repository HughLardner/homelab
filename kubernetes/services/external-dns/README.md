# External-DNS

Automated DNS record management for Kubernetes resources using Cloudflare.

## Overview

External-DNS automatically synchronizes DNS records in Cloudflare with Kubernetes LoadBalancer Services and Traefik IngressRoutes. When a LoadBalancer IP changes or a new IngressRoute is created, external-dns automatically updates DNS records.

### Architecture

```
┌──────────────┐     ┌────────────────┐     ┌──────────────┐
│   Traefik    │────▶│  External-DNS  │────▶│  Cloudflare  │
│ LoadBalancer │     │   Controller   │     │     API      │
└──────────────┘     └────────────────┘     └──────────────┘
      │                      │
      │                      ▼
      ▼              ┌────────────────┐
┌──────────────┐    │ IngressRoutes  │
│   Services   │    │  (ArgoCD, etc) │
└──────────────┘    └────────────────┘

DNS Records Created:
- A:     traefik.silverseekers.org → 192.168.10.145
- CNAME: argocd.silverseekers.org  → traefik.silverseekers.org
- CNAME: grafana.silverseekers.org → traefik.silverseekers.org
- TXT:   _external-dns.argocd...   → ownership tracking
```

## Features

- **Automatic DNS Updates**: LoadBalancer IP changes automatically update DNS
- **Traefik IngressRoute Support**: Watches Traefik CRDs for hostname changes
- **TXT Record Ownership**: Prevents conflicts with manually managed records
- **High Availability**: 2 replicas with leader election
- **Safe Defaults**: Starts with upsert-only mode (no deletions)
- **Cloudflare Integration**: Direct API integration with secure token

## Installation

### Prerequisites

- Kubernetes cluster with:
  - Traefik ingress controller with LoadBalancer
  - Cert-manager for TLS (optional but recommended)
  - Sealed Secrets for secret management
- Cloudflare account with:
  - API token with DNS:Edit permissions
  - Domain configured (e.g., silverseekers.org)

### Via Ansible (Recommended)

```bash
# Ensure cloudflare_api_token is set in ansible/inventory/hosts.yml
make external-dns-install
```

### Via ArgoCD (GitOps)

```bash
# Apply the Application manifest
kubectl apply -f kubernetes/applications/external-dns/application.yaml

# ArgoCD will automatically sync
```

### Manual via Helm

```bash
# Add Helm repository
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
helm repo update

# Install
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --create-namespace \
  --values kubernetes/services/external-dns/values.yaml
```

## Configuration

### Cloudflare API Token

The API token must have **DNS:Edit** permission for your zone:

1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Create Token → Edit zone DNS template
3. Zone Resources: Include → Specific zone → Your domain
4. Copy the token

### Secrets Management

Create sealed secret:

```bash
# Extract token from inventory
TOKEN=$(grep cloudflare_api_token ansible/inventory/hosts.yml | awk '{print $2}')

# Create namespace
kubectl create namespace external-dns

# Seal the secret
kubectl create secret generic cloudflare-api-token \
  --namespace=external-dns \
  --from-literal=cloudflare_api_token="$TOKEN" \
  --dry-run=client -o yaml | \
kubeseal -o yaml > kubernetes/services/external-dns/cloudflare-api-token-sealed.yaml

# Commit to Git
git add kubernetes/services/external-dns/cloudflare-api-token-sealed.yaml
git commit -m "Add Cloudflare sealed secret for external-dns"
```

### Annotations

#### For LoadBalancer Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "traefik.silverseekers.org"
    external-dns.alpha.kubernetes.io/ttl: "300"  # Optional: 5 minute TTL
spec:
  type: LoadBalancer
```

Creates A record: `traefik.silverseekers.org → 192.168.10.145`

#### For Traefik IngressRoutes

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    external-dns.alpha.kubernetes.io/target: "traefik.silverseekers.org"
spec:
  routes:
    - match: Host(`argocd.silverseekers.org`)
```

Creates CNAME: `argocd.silverseekers.org → traefik.silverseekers.org`

## Operations

### Verify Installation

```bash
# Check deployment
make external-dns-status

# Expected output:
# NAME           READY   UP-TO-DATE   AVAILABLE   AGE
# external-dns   2/2     2            2           5m

# Check pods
kubectl get pods -n external-dns
```

### View Logs

```bash
# Follow logs
make external-dns-logs

# Or directly
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f
```

### Check DNS Operations

```bash
# See recent DNS changes
make external-dns-records

# View full logs with operations
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | \
  grep -E "(CREATE|UPDATE|DELETE)"
```

### Verify DNS Records

```bash
# Check A record for Traefik LoadBalancer
dig traefik.silverseekers.org +short

# Check CNAME records for applications
dig argocd.silverseekers.org +short
dig grafana.silverseekers.org +short

# Check TXT ownership records
dig _external-dns.argocd.silverseekers.org TXT +short
```

## Troubleshooting

### DNS Records Not Created

**Symptoms**: external-dns running but no DNS records in Cloudflare

**Debug**:
```bash
# Check if sources are discovered
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | \
  grep "endpoints from"

# Verify annotations
kubectl get ingressroute argocd-server -n argocd -o yaml | \
  grep external-dns

# Check for errors
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | \
  grep -i error
```

**Common Causes**:
- Missing annotations on resources
- Wrong annotation syntax
- Domain not in `domainFilters`
- Cloudflare API token expired

### Permission Denied Errors

**Symptoms**: Logs show "403 Forbidden" or "Access Denied"

**Debug**:
```bash
# Test API token manually
TOKEN=$(kubectl get secret cloudflare-api-token -n external-dns \
  -o jsonpath='{.data.cloudflare_api_token}' | base64 -d)

curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $TOKEN"
```

**Fix**: Verify token has Zone:DNS:Edit permission in Cloudflare

### Records Not Deleted

**Symptoms**: Old DNS records remain after resource deletion

**Cause**: Using `policy: upsert-only`

**Fix**:
1. Records will persist (safe behavior)
2. Upgrade to `policy: sync` to enable deletion
3. Or manually delete records from Cloudflare

### High API Rate Limiting

**Symptoms**: Frequent "rate limit exceeded" errors

**Fix**:
```yaml
# Increase sync interval in values.yaml
interval: 5m  # Default is 1m
```

## Safety and Policies

### Upsert-Only Mode (Default)

- **Behavior**: Creates and updates records only, never deletes
- **Use Case**: Initial deployment and testing
- **Safety**: Very safe, no risk of deleting records
- **Limitation**: Orphaned records remain

### Sync Mode

- **Behavior**: Full management including creation, updates, AND deletion
- **Use Case**: Production after validation
- **Safety**: Moderate risk of deleting records
- **Requirement**: TXT ownership records must match

**Upgrade Path**:
```bash
# After 48 hours of stable upsert-only operation
# Edit values.yaml
policy: sync

# Apply via GitOps or Helm upgrade
```

### TXT Ownership

External-DNS creates TXT records to track ownership:

```
_external-dns.argocd.silverseekers.org TXT "heritage=external-dns,owner=k3s-cluster"
```

Only records with matching ownership markers will be deleted in sync mode.

## Monitoring

### Prometheus Metrics

External-DNS exposes metrics on `:7979/metrics`:

- `external_dns_registry_endpoints_total` - Total managed endpoints
- `external_dns_source_endpoints_total` - Discovered endpoints
- `external_dns_registry_errors_total` - Cloudflare API errors
- `external_dns_controller_last_sync_timestamp_seconds` - Last sync

### Grafana Dashboard

Create a dashboard with:
- Managed records count
- Sync success rate
- API error rate
- Sync latency

### Alerts

Recommended Prometheus alerts:

```yaml
- alert: ExternalDNSSyncFailure
  expr: increase(external_dns_registry_errors_total[5m]) > 5
  annotations:
    summary: "External-DNS failing to sync with Cloudflare"

- alert: ExternalDNSNotRunning
  expr: up{job="external-dns"} == 0
  annotations:
    summary: "External-DNS pod is down"
```

## Rollback

### Immediate Rollback

```bash
# Scale to 0 replicas
kubectl scale deployment external-dns -n external-dns --replicas=0

# Manually restore DNS in Cloudflare dashboard
```

### Full Removal

```bash
# Via ArgoCD
kubectl delete application external-dns -n argocd

# Via Helm
helm uninstall external-dns -n external-dns

# Delete namespace
kubectl delete namespace external-dns

# Manually clean up TXT records in Cloudflare
```

## References

- [External-DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Cloudflare Provider Guide](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md)
- [Traefik IngressRoute Support](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/traefik-proxy.md)
- [TXT Registry](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/proposal/registry.md)

## Support

For issues or questions:
1. Check logs: `make external-dns-logs`
2. Verify Cloudflare token permissions
3. Check annotations on resources
4. Review external-dns GitHub issues
