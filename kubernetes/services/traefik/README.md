# Traefik Ingress Controller

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy.

## Quick Reference

```bash
# Install Traefik (automated)
make traefik-install

# View Traefik pods
kubectl get pods -n traefik

# View Traefik service
kubectl get svc -n traefik

# View IngressRoutes
kubectl get ingressroute -A

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

## Features

- **HTTP/HTTPS Routing**: Intelligent request routing based on rules
- **Automatic TLS**: Integration with cert-manager for automatic certificates
- **Load Balancing**: Built-in load balancing across backend services
- **Middlewares**: Request/response transformation and security
- **Dashboard**: Web UI for monitoring routes and services
- **Metrics**: Prometheus metrics integration
- **Dynamic Configuration**: Automatic discovery of services
- **WebSocket Support**: Native WebSocket proxying
- **HTTP/2 & gRPC**: Full HTTP/2 and gRPC support

## Architecture

### Service Types

- **LoadBalancer**: Uses MetalLB to assign external IP
- **HTTP (Port 80)**: Automatically redirects to HTTPS
- **HTTPS (Port 443)**: TLS-enabled ingress
- **Dashboard (Port 9000)**: Internal dashboard access
- **Metrics (Port 9100)**: Prometheus metrics endpoint

### Integration Points

- **Cert-Manager**: Automatic TLS certificate issuance via annotations
- **MetalLB**: LoadBalancer IP allocation
- **Longhorn**: Persistent storage for Traefik data
- **Prometheus**: Metrics collection and monitoring

## Installation

### Automated (Ansible)

```bash
# Install Traefik with dashboard and middlewares
make traefik-install

# Verify installation
kubectl get pods -n traefik
kubectl get svc -n traefik
kubectl get ingressclass

# Access dashboard (if configured)
# https://traefik.yourdomain.com
```

### Manual (Helm)

```bash
# Add Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --values kubernetes/services/traefik/values.yaml

# Apply dashboard and middlewares
kubectl apply -k kubernetes/services/traefik/
```

### Manual (kubectl)

```bash
# Install Traefik via Helm first
helm install traefik traefik/traefik --namespace traefik --create-namespace

# Apply custom configurations
kubectl apply -f kubernetes/services/traefik/dashboard-ingressroute.yaml
kubectl apply -f kubernetes/services/traefik/middlewares.yaml
```

## Configuration

### Dashboard Access

The Traefik dashboard is exposed via IngressRoute with:
- **TLS Certificate**: Automatically issued by cert-manager
- **Basic Authentication**: Username/password protection
- **Domain**: Configured via `traefik_dashboard_domain` variable

**Default credentials** (if using automated deployment):
- Username: `admin`
- Password: Set during installation (stored in Secret)

### Middlewares

Pre-configured middlewares for common use cases:

**1. traefik-dashboard-auth** - Basic authentication for dashboard
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: traefik-dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth
```

**2. security-headers** - Security HTTP headers
```yaml
# Includes: X-Frame-Options, X-XSS-Protection, HSTS, etc.
```

**3. rate-limit** - Rate limiting (100 req/s, burst 50)
```yaml
# Prevents abuse and DoS attacks
```

**4. compress** - Response compression
```yaml
# Reduces bandwidth usage
```

**5. https-redirect** - HTTP to HTTPS redirect
```yaml
# Forces HTTPS for all traffic
```

**6. ip-whitelist-local** - IP whitelist for internal networks
```yaml
# Restricts access to RFC1918 private networks
```

## Usage

### Basic Ingress (Standard Kubernetes)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.middlewares: traefik-security-headers@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - myapp.yourdomain.com
    secretName: myapp-tls
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

### IngressRoute (Traefik CRD)

```yaml
---
# Certificate (managed by cert-manager)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
spec:
  secretName: myapp-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - myapp.yourdomain.com

---
# IngressRoute (Traefik native)
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.yourdomain.com`)
      kind: Rule
      middlewares:
        - name: security-headers
          namespace: traefik
        - name: rate-limit
          namespace: traefik
      services:
        - name: my-app
          port: 80
  tls:
    secretName: myapp-tls
```

### IngressRoute with Path Matching

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: multi-path-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.yourdomain.com`) && PathPrefix(`/api`)
      kind: Rule
      services:
        - name: api-service
          port: 8080
    - match: Host(`myapp.yourdomain.com`) && PathPrefix(`/web`)
      kind: Rule
      services:
        - name: web-service
          port: 80
  tls:
    secretName: myapp-tls
```

### Custom Middleware Example

```yaml
---
# Custom rate limit for API
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: api-rate-limit
  namespace: default
spec:
  rateLimit:
    average: 10
    burst: 5
    period: 1s

---
# Use in IngressRoute
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: api-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`api.yourdomain.com`)
      kind: Rule
      middlewares:
        - name: api-rate-limit  # Local middleware
        - name: security-headers  # Global middleware
          namespace: traefik
      services:
        - name: api-service
          port: 8080
  tls:
    secretName: api-tls
```

## Common Tasks

### Check Traefik Status

```bash
# View Traefik pods
kubectl get pods -n traefik

# Check Traefik service and LoadBalancer IP
kubectl get svc -n traefik traefik

# View all IngressRoutes
kubectl get ingressroute -A

# View all Ingresses
kubectl get ingress -A

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100
```

### Access Traefik Dashboard

```bash
# Via configured domain (if IngressRoute is set up)
# https://traefik.yourdomain.com

# Via port-forward (without IngressRoute)
kubectl port-forward -n traefik svc/traefik 9000:9000

# Then access: http://localhost:9000/dashboard/
```

### Update Dashboard Credentials

```bash
# Generate new password hash
htpasswd -nB admin
# Example output: admin:$2y$05$...

# Update secret
kubectl create secret generic traefik-dashboard-auth \
  --from-literal=users='admin:$2y$05$...' \
  --namespace traefik \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Traefik to pick up changes
kubectl rollout restart deployment -n traefik traefik
```

### Test TLS Certificate

```bash
# Check certificate
openssl s_client -connect myapp.yourdomain.com:443 -servername myapp.yourdomain.com

# View certificate details
echo | openssl s_client -connect myapp.yourdomain.com:443 -servername myapp.yourdomain.com 2>/dev/null | openssl x509 -text -noout
```

### View Metrics

```bash
# Port-forward metrics endpoint
kubectl port-forward -n traefik svc/traefik 9100:9100

# View metrics
curl http://localhost:9100/metrics
```

## Troubleshooting

### Traefik Not Starting

```bash
# Check pod status
kubectl get pods -n traefik

# View pod events
kubectl describe pod -n traefik <pod-name>

# Check logs
kubectl logs -n traefik <pod-name>

# Common issues:
# - PVC not bound (check Longhorn)
# - Port conflicts (check other services using 80/443)
# - Invalid configuration (check values.yaml)
```

### IngressRoute Not Working

```bash
# Check IngressRoute status
kubectl describe ingressroute -n <namespace> <name>

# Check if service exists
kubectl get svc -n <namespace>

# Check Traefik logs for errors
kubectl logs -n traefik -l app.kubernetes.io/name=traefik | grep error

# Verify IngressRoute is using correct service name/port
kubectl get ingressroute -n <namespace> <name> -o yaml

# Common issues:
# - Service name mismatch
# - Wrong namespace
# - TLS certificate not ready
# - Middleware not found
```

### Certificate Not Issued

```bash
# Check certificate status
kubectl describe certificate -n <namespace> <name>

# Check certificate request
kubectl get certificaterequest -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Verify ClusterIssuer is ready
kubectl get clusterissuer

# Common issues:
# - DNS challenge failing (check Cloudflare API token)
# - Rate limit exceeded (use staging issuer first)
# - Invalid domain name
```

### Dashboard Not Accessible

```bash
# Check IngressRoute
kubectl get ingressroute -n traefik traefik-dashboard

# Check certificate
kubectl get certificate -n traefik traefik-dashboard-tls

# Check authentication secret
kubectl get secret -n traefik traefik-dashboard-auth

# Test without auth (temporarily)
# Edit IngressRoute to remove middleware

# Access via port-forward
kubectl port-forward -n traefik svc/traefik 9000:9000
# Access: http://localhost:9000/dashboard/
```

### LoadBalancer Stuck in Pending

```bash
# Check service
kubectl get svc -n traefik traefik

# Check MetalLB status
kubectl get pods -n metallb-system

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Check IP pool
kubectl get ipaddresspool -n metallb-system

# Common issues:
# - MetalLB not installed
# - IP pool exhausted
# - L2Advertisement not configured
```

## Best Practices

### Security

1. **Use HTTPS**: Always redirect HTTP to HTTPS
2. **Authentication**: Protect dashboard with strong authentication
3. **Rate Limiting**: Apply rate limits to public services
4. **Security Headers**: Use security-headers middleware
5. **IP Whitelisting**: Restrict admin interfaces to trusted IPs

### Performance

1. **Multiple Replicas**: Run 2+ Traefik pods for high availability
2. **Resource Limits**: Set appropriate CPU/memory limits
3. **Compression**: Enable compression for text responses
4. **Caching**: Use middleware for caching when appropriate
5. **Connection Limits**: Configure max connections per service

### Certificate Management

1. **Test with Staging**: Always test with Let's Encrypt staging first
2. **Wildcard Certificates**: Use wildcard certs to reduce certificate count
3. **Certificate Reuse**: Share certificates across multiple services
4. **Monitor Expiry**: Set up alerts for expiring certificates

### Monitoring

1. **Enable Metrics**: Configure Prometheus metrics
2. **Access Logs**: Enable access logging for audit trail
3. **Dashboard**: Regularly check dashboard for errors
4. **Alerts**: Set up alerts for Traefik pod failures

## Integration with Ansible

**These manifest files are the single source of truth for Traefik configuration.**

The Ansible playbook (`ansible/playbooks/traefik.yml`) uses these files:
- Templates Helm values with variables from inventory
- Installs Traefik via Helm chart
- Applies dashboard IngressRoute and middlewares
- Creates dashboard authentication secret

### Configuration Workflow

1. **Initial Deployment** (Automated):
   ```bash
   make traefik-install  # Ansible templates and installs
   ```

2. **Manual Changes** (Day-2 Operations):
   ```bash
   # Edit middleware
   vim kubernetes/services/traefik/middlewares.yaml

   # Apply changes
   kubectl apply -f kubernetes/services/traefik/middlewares.yaml

   # Or re-run Ansible
   make traefik-install
   ```

3. **GitOps** (Future):
   Point ArgoCD/Flux at `kubernetes/services/traefik/` directory

## Configuration Variables

From Ansible inventory (via Terraform):

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `traefik_replicas` | No | 2 | Number of Traefik pods |
| `traefik_service_type` | No | LoadBalancer | Service type (LoadBalancer/NodePort) |
| `traefik_loadbalancer_ip` | No | "" | Static LoadBalancer IP (MetalLB) |
| `traefik_storage_class` | No | longhorn | StorageClass for persistence |
| `traefik_dashboard_domain` | Yes | - | Dashboard hostname (e.g., traefik.example.com) |
| `traefik_cert_issuer` | No | letsencrypt-staging | ClusterIssuer for dashboard TLS |
| `traefik_dashboard_username` | No | admin | Dashboard basic auth username |
| `traefik_dashboard_password` | Yes | - | Dashboard basic auth password |

## Examples

### Simple HTTP Service

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: nginxdemos/hello
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
  namespace: default
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 80

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - hello.yourdomain.com
    secretName: hello-world-tls
  rules:
  - host: hello.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 80
```

### Multiple Domains/Services

```yaml
---
# Certificate for multiple domains
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: multi-domain-tls
  namespace: default
spec:
  secretName: multi-domain-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app1.yourdomain.com
    - app2.yourdomain.com
    - app3.yourdomain.com

---
# IngressRoute for multiple services
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: multi-service
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app1.yourdomain.com`)
      kind: Rule
      services:
        - name: app1-service
          port: 80
    - match: Host(`app2.yourdomain.com`)
      kind: Rule
      services:
        - name: app2-service
          port: 8080
    - match: Host(`app3.yourdomain.com`)
      kind: Rule
      services:
        - name: app3-service
          port: 3000
  tls:
    secretName: multi-domain-tls
```

### WebSocket Application

```yaml
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: websocket-app
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`ws.yourdomain.com`)
      kind: Rule
      services:
        - name: websocket-service
          port: 8080
  tls:
    secretName: websocket-tls
```

### TCP Service (Non-HTTP)

```yaml
---
# IngressRouteTCP for non-HTTP services
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRouteTCP
metadata:
  name: postgres
  namespace: default
spec:
  entryPoints:
    - postgres  # Must define custom entrypoint in values.yaml
  routes:
    - match: HostSNI(`*`)
      services:
        - name: postgres
          port: 5432
  tls:
    passthrough: true
```

## References

- [Official Documentation](https://doc.traefik.io/traefik/)
- [Kubernetes Ingress](https://doc.traefik.io/traefik/providers/kubernetes-ingress/)
- [Kubernetes CRD](https://doc.traefik.io/traefik/providers/kubernetes-crd/)
- [Middlewares](https://doc.traefik.io/traefik/middlewares/overview/)
- [Routing](https://doc.traefik.io/traefik/routing/overview/)
- [TLS](https://doc.traefik.io/traefik/https/tls/)
- [Let's Encrypt](https://doc.traefik.io/traefik/https/acme/)
- [Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [GitHub Repository](https://github.com/traefik/traefik)
