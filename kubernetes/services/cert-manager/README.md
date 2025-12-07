# Cert-Manager

Cert-Manager automates the management and issuance of TLS certificates in Kubernetes clusters.

## Quick Reference

```bash
# Install Cert-Manager (automated)
make cert-manager-install

# View ClusterIssuers
kubectl get clusterissuer

# View certificates
kubectl get certificate -A

# View certificate requests
kubectl get certificaterequest -A

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

## Features

- **Automated Certificate Issuance**: Request certificates declaratively
- **Automatic Renewal**: Renews certificates before expiration
- **Multiple Issuers**: Let's Encrypt, self-signed, Vault, etc.
- **DNS-01 Challenge**: Wildcard certificate support via Cloudflare
- **HTTP-01 Challenge**: Domain validation via Ingress
- **Webhook Integration**: Automatic TLS for Ingress resources

## Configuration

### ClusterIssuers

Three ClusterIssuers are configured:

**1. letsencrypt-staging** - For testing
- Uses Let's Encrypt staging server
- Avoids rate limits during testing
- Certificates show as untrusted
- Use for initial setup validation

**2. letsencrypt-prod** - For production
- Uses Let's Encrypt production server
- Issues trusted certificates
- Subject to rate limits (50 certificates/week)
- Use after testing with staging

**3. selfsigned** - For internal services
- No external dependencies
- Instant issuance
- Not publicly trusted
- Perfect for internal/development services

### DNS Challenge

Using Cloudflare DNS-01 challenge enables:
- **Wildcard certificates**: `*.yourdomain.com`
- **Internal services**: No need for public HTTP endpoint
- **Firewall-friendly**: No inbound traffic required

## Installation

### Automated (Ansible)

```bash
# Install cert-manager with ClusterIssuers
make cert-manager-install

# Verify installation
kubectl get pods -n cert-manager
kubectl get clusterissuer

# Check ClusterIssuer status
kubectl describe clusterissuer letsencrypt-prod
```

### Manual (Helm)

```bash
# Add Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --values kubernetes/services/cert-manager/values.yaml

# Apply ClusterIssuers (after installation)
kubectl apply -k kubernetes/services/cert-manager/
```

### Manual (kubectl)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Apply ClusterIssuers
kubectl apply -f kubernetes/services/cert-manager/cluster-issuer-letsencrypt-staging.yaml
kubectl apply -f kubernetes/services/cert-manager/cluster-issuer-letsencrypt-prod.yaml
kubectl apply -f kubernetes/services/cert-manager/cluster-issuer-selfsigned.yaml
```

## Usage

### Request Certificate (Declarative)

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - myapp.yourdomain.com
    - www.myapp.yourdomain.com
```

### Request Wildcard Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: default
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.yourdomain.com"
    - yourdomain.com
```

### Request Self-Signed Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: internal-app-tls
  namespace: default
spec:
  secretName: internal-app-tls
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
  dnsNames:
    - internal.local
```

### Automatic Certificate via Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - myapp.yourdomain.com
    secretName: my-app-tls  # Cert-manager creates this
  rules:
  - host: myapp.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

### Automatic Certificate via Traefik IngressRoute

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.yourdomain.com`)
      kind: Rule
      services:
        - name: my-app
          port: 80
  tls:
    secretName: my-app-tls  # Cert-manager creates this
```

## Common Tasks

### Check Certificate Status

```bash
# List all certificates
kubectl get certificate -A

# Describe specific certificate
kubectl describe certificate -n default my-app-tls

# Check certificate secret
kubectl get secret -n default my-app-tls

# View certificate details
kubectl get secret -n default my-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Check Certificate Request

```bash
# View certificate requests
kubectl get certificaterequest -A

# Describe specific request
kubectl describe certificaterequest -n default my-app-tls-xxxxx

# Check order status
kubectl get order -A
kubectl describe order -n default my-app-tls-xxxxx-xxxxx

# Check challenge status
kubectl get challenge -A
kubectl describe challenge -n default my-app-tls-xxxxx-xxxxx-xxxxx
```

### Force Certificate Renewal

```bash
# Delete certificate to trigger renewal
kubectl delete certificate -n default my-app-tls

# Or use cmctl (cert-manager CLI)
cmctl renew -n default my-app-tls

# Or annotate certificate
kubectl annotate certificate -n default my-app-tls cert-manager.io/issue-temporary-certificate="true"
```

### Test Certificate Issuance

```bash
# Test with staging issuer first
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.yourdomain.com
EOF

# Wait for ready
kubectl wait --for=condition=ready certificate/test-cert -n default --timeout=300s

# Check status
kubectl describe certificate test-cert -n default

# View certificate
kubectl get secret test-cert-tls -n default -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A2 "Issuer:"

# Cleanup
kubectl delete certificate test-cert -n default
```

### Switch from Staging to Production

```bash
# Delete staging certificate
kubectl delete certificate -n default my-app-tls

# Update to use production issuer
kubectl patch certificate -n default my-app-tls -p '{"spec":{"issuerRef":{"name":"letsencrypt-prod"}}}'

# Or recreate with production issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: letsencrypt-prod  # Changed from staging
    kind: ClusterIssuer
  dnsNames:
    - myapp.yourdomain.com
EOF
```

## Troubleshooting

### Certificate Not Ready

```bash
# Check certificate status
kubectl describe certificate -n default my-app-tls

# Look for errors in Events section
# Common issues:
# - DNS validation failed
# - Rate limit exceeded
# - Invalid Cloudflare API token

# Check certificate request
kubectl get certificaterequest -n default

# Check order
kubectl get order -n default

# Check challenge
kubectl get challenge -n default
kubectl describe challenge -n default <challenge-name>
```

### DNS Challenge Failing

```bash
# Verify Cloudflare secret exists
kubectl get secret -n cert-manager cloudflare-api-token

# Check secret contents
kubectl get secret -n cert-manager cloudflare-api-token -o yaml

# Test Cloudflare API token manually
CLOUDFLARE_API_TOKEN=$(kubectl get secret -n cert-manager cloudflare-api-token -o jsonpath='{.data.api-token}' | base64 -d)
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

### Rate Limit Exceeded

```bash
# Let's Encrypt rate limits:
# - 50 certificates per registered domain per week
# - 5 duplicate certificates per week

# Check current certificates
# Use staging issuer for testing
# Wait 7 days for rate limit reset

# View rate limits
curl -s https://acme-v02.api.letsencrypt.org/directory | jq .meta.termsOfService
```

### Webhook Not Ready

```bash
# Check webhook pod
kubectl get pods -n cert-manager -l app=webhook

# Check webhook logs
kubectl logs -n cert-manager -l app=webhook

# Test webhook
kubectl get validatingwebhookconfiguration cert-manager-webhook
kubectl describe validatingwebhookconfiguration cert-manager-webhook

# Restart webhook if needed
kubectl rollout restart deployment -n cert-manager cert-manager-webhook
```

### Certificate Shows as Invalid

```bash
# Check certificate expiry
kubectl get secret -n default my-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Check certificate issuer
kubectl get secret -n default my-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer

# Verify certificate chain
kubectl get secret -n default my-app-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl verify

# Test with openssl s_client
openssl s_client -connect myapp.yourdomain.com:443 -servername myapp.yourdomain.com
```

## Best Practices

### Certificate Management

1. **Test with Staging**: Always test with staging issuer first
2. **Use Wildcard Certificates**: Reduce number of certificates needed
3. **Monitor Expiry**: Set up alerts for expiring certificates
4. **Backup Secrets**: Back up certificate secrets regularly

### DNS Challenge

1. **Restrict API Token**: Use Cloudflare API token with minimal permissions
2. **Zone-Specific**: Create token for specific DNS zone only
3. **Rotate Tokens**: Regularly rotate API tokens
4. **Monitor Usage**: Watch for unauthorized DNS changes

### Rate Limits

1. **Use Staging**: Test thoroughly with staging before production
2. **Plan Deployments**: Avoid recreating certificates unnecessarily
3. **Reuse Certificates**: Share certificates across services when possible
4. **Monitor Limits**: Track certificate issuance

### Security

1. **Limit Secret Access**: Use RBAC to restrict secret access
2. **Separate Namespaces**: Use different namespaces for different apps
3. **Audit Access**: Monitor certificate secret access
4. **Rotate Credentials**: Regularly rotate Cloudflare API tokens

## Integration with Ansible

**These manifest files are the single source of truth for Cert-Manager configuration.**

The Ansible playbook (`ansible/playbooks/cert-manager.yml`) uses these files:
- Templates ClusterIssuers with variables from inventory
- Creates Cloudflare API token secret
- Applies cert-manager and ClusterIssuers to the cluster

### Configuration Workflow

1. **Initial Deployment** (Automated):
   ```bash
   make cert-manager-install  # Ansible templates and applies
   ```

2. **Manual Changes** (Day-2 Operations):
   ```bash
   # Edit ClusterIssuer
   vim kubernetes/services/cert-manager/cluster-issuer-letsencrypt-prod.yaml

   # Apply changes
   kubectl apply -f kubernetes/services/cert-manager/cluster-issuer-letsencrypt-prod.yaml

   # Or re-run Ansible
   make cert-manager-install
   ```

3. **GitOps** (Future):
   Point ArgoCD/Flux at `kubernetes/services/cert-manager/` directory

## Configuration Variables

From Ansible inventory (via Terraform):

| Variable | Required | Description |
|----------|----------|-------------|
| `cert_manager_email` | Yes | Email for Let's Encrypt notifications |
| `cert_manager_domain` | Yes | DNS zone for certificates |
| `cloudflare_email` | Yes | Cloudflare account email |
| `cloudflare_api_token` | Yes | Cloudflare API token (stored in secrets) |

## Examples

### WordPress with TLS

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - blog.yourdomain.com
    secretName: wordpress-tls
  rules:
  - host: blog.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress
            port:
              number: 80
```

### Wildcard Certificate for Multiple Services

```yaml
---
# Create one wildcard certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-yourdomain-com
  namespace: default
spec:
  secretName: wildcard-yourdomain-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.yourdomain.com"
    - yourdomain.com
---
# Use in multiple Ingresses
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app1
spec:
  tls:
  - hosts:
    - app1.yourdomain.com
    secretName: wildcard-yourdomain-com-tls  # Reuse certificate
  rules:
  - host: app1.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app2
spec:
  tls:
  - hosts:
    - app2.yourdomain.com
    secretName: wildcard-yourdomain-com-tls  # Reuse same certificate
  rules:
  - host: app2.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
```

## References

- [Official Documentation](https://cert-manager.io/docs/)
- [Configuration Guide](https://cert-manager.io/docs/configuration/)
- [Tutorials](https://cert-manager.io/docs/tutorials/)
- [Troubleshooting Guide](https://cert-manager.io/docs/troubleshooting/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [GitHub Repository](https://github.com/cert-manager/cert-manager)
