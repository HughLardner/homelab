# Adding Applications to the Homelab Cluster

This guide explains how to add new applications to your homelab cluster, leveraging the existing services:

- **ArgoCD** - GitOps deployment
- **Traefik** - Ingress controller with HTTPS
- **cert-manager** - Automatic TLS certificates
- **Authelia** - SSO/2FA authentication
- **Longhorn** - Persistent storage
- **Sealed Secrets** - Encrypted secrets for GitOps

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Generator Script](#generator-script)
3. [Application Types](#application-types)
4. [Directory Structure](#directory-structure)
5. [Step-by-Step Guide](#step-by-step-guide)
6. [Templates](#templates)
7. [Available Middlewares](#available-middlewares)
8. [Storage Options](#storage-options)
9. [Secrets Management](#secrets-management)
10. [Testing Locally](#testing-locally)
11. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Option 1: Use the Generator Script (Recommended)

```bash
# Generate a complete application scaffold
make new-app APP=myapp

# With options
make new-app APP=myapp PORT=3000 AUTH=true STORAGE=10Gi

# Or use the script directly
./scripts/new-app.sh myapp --port 3000 --auth --storage 10Gi
```

Then customize and deploy:

```bash
# 1. Review and customize generated files
vim kubernetes/applications/myapp/values.yaml

# 2. Add secrets to config/secrets.yml (if needed)
# 3. Seal secrets
make seal-secrets

# 4. Commit and push
git add kubernetes/applications/myapp
git commit -m "Add myapp application"
git push

# 5. ArgoCD automatically deploys it!
```

### Option 2: Manual Setup

To manually create an application called `myapp`:

```bash
# 1. Create application directory
mkdir -p kubernetes/applications/myapp/{templates,secrets}

# 2. Create required files (see templates below)
# - Chart.yaml
# - values.yaml
# - application.yaml
# - templates/ingressroute.yaml
# - templates/certificate.yaml

# 3. Add secrets to config/secrets.yml (if needed)

# 4. Seal secrets
make seal-secrets

# 5. Commit and push
git add kubernetes/applications/myapp
git commit -m "Add myapp application"
git push

# 6. ArgoCD automatically deploys it via root-app
```

---

## Generator Script

The `scripts/new-app.sh` script creates a complete application scaffold with all required files.

### Usage

```bash
# Via Makefile
make new-app APP=myapp [PORT=8080] [AUTH=true] [STORAGE=5Gi] [IMAGE=nginx:alpine]

# Via script directly
./scripts/new-app.sh myapp [OPTIONS]
```

### Options

| Option   | Makefile            | Script                | Default      | Description                  |
| -------- | ------------------- | --------------------- | ------------ | ---------------------------- |
| App name | `APP=myapp`         | `myapp`               | (required)   | Application name (lowercase) |
| Port     | `PORT=3000`         | `--port 3000`         | 8080         | Service port                 |
| Auth     | `AUTH=true`         | `--auth`              | false        | Enable Authelia SSO          |
| Storage  | `STORAGE=10Gi`      | `--storage 10Gi`      | disabled     | Enable Longhorn PVC          |
| Image    | `IMAGE=python:3.11` | `--image python:3.11` | nginx:alpine | Container image              |
| Wave     | `WAVE=6`            | `--wave 6`            | 5            | ArgoCD sync wave             |
| Type     | -                   | `--type service`      | application  | `application` or `service`   |

### Examples

```bash
# Simple static website
make new-app APP=mywebsite

# API with auth and storage
make new-app APP=myapi PORT=8000 AUTH=true STORAGE=5Gi IMAGE=python:3.11

# Database service
make new-app APP=postgres PORT=5432 STORAGE=20Gi IMAGE=postgres:16

# Using script with all options
./scripts/new-app.sh myapp \
  --port 3000 \
  --auth \
  --storage 10Gi \
  --image myregistry/myapp:v1.0.0 \
  --wave 6
```

### Generated Files

```
kubernetes/applications/myapp/
├── application.yaml      # ArgoCD Application manifest
├── Chart.yaml            # Helm chart metadata
├── values.yaml           # Configurable values (port, image, auth, storage)
├── README.md             # Auto-generated documentation
├── templates/
│   ├── deployment.yaml   # Kubernetes Deployment
│   ├── service.yaml      # ClusterIP Service
│   ├── ingressroute.yaml # Traefik HTTPS ingress (with optional Authelia)
│   ├── certificate.yaml  # TLS certificate from cert-manager
│   └── pvc.yaml          # PersistentVolumeClaim (if storage enabled)
└── secrets/
    └── .gitkeep          # Placeholder for sealed secrets
```

### Post-Generation Steps

1. **Review values.yaml** - Customize image, resources, environment
2. **Add secrets** - Add to `config/secrets.yml` if needed
3. **Seal secrets** - Run `make seal-secrets`
4. **Deploy** - Commit and push to Git

```bash
# Complete workflow
make new-app APP=myapp PORT=3000 AUTH=true
vim kubernetes/applications/myapp/values.yaml  # Customize
git add kubernetes/applications/myapp
git commit -m "Add myapp application"
git push
# ArgoCD deploys to https://myapp.silverseekers.org
```

---

## Application Types

### Type 1: Infrastructure Services

Located in `kubernetes/services/`

These support the cluster (cert-manager, traefik, longhorn, etc.)

### Type 2: Workload Applications

Located in `kubernetes/applications/`

These run on the cluster (homepage, monitoring, your apps)

**Both types are automatically discovered by `root-app.yaml`** when they have an `application.yaml` file.

---

## Directory Structure

```
kubernetes/applications/myapp/
├── application.yaml          # ArgoCD Application (REQUIRED)
├── Chart.yaml                # Helm chart metadata (REQUIRED)
├── values.yaml               # Default values (REQUIRED)
├── myapp-values.yaml         # Upstream chart values (if using external chart)
├── templates/                # Kubernetes templates
│   ├── deployment.yaml       # Your app deployment
│   ├── service.yaml          # Service exposing your app
│   ├── ingressroute.yaml     # Traefik IngressRoute for HTTPS
│   ├── certificate.yaml      # TLS certificate from cert-manager
│   └── configmap.yaml        # App configuration
├── secrets/                  # Sealed secrets directory
│   └── myapp-sealed.yaml     # Encrypted secrets
└── README.md                 # Documentation
```

---

## Step-by-Step Guide

### Step 1: Create Chart.yaml

```yaml
# kubernetes/applications/myapp/Chart.yaml
apiVersion: v2
name: myapp
description: My Application
type: application
version: 1.0.0
appVersion: "1.0.0"
```

### Step 2: Create values.yaml

```yaml
# kubernetes/applications/myapp/values.yaml
# This chart inherits values from config/homelab.yaml
# Access via: .Values.global.domain, .Values.services.myapp.domain, etc.

# Add any chart-specific defaults here
replicaCount: 1
image:
  repository: myapp/myapp
  tag: latest
  pullPolicy: IfNotPresent

# Service configuration
service:
  port: 8080
  type: ClusterIP

# Enable/disable Authelia protection
auth_enabled: true

# Storage configuration
persistence:
  enabled: true
  size: 5Gi
  storageClass: longhorn
```

### Step 3: Create Application Manifest

```yaml
# kubernetes/applications/myapp/application.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    # Sync wave controls deployment order
    # Lower numbers deploy first
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default

  # Multiple sources pattern (recommended)
  sources:
    # 1. Your application chart
    - repoURL: https://github.com/YourUser/homelab.git
      targetRevision: HEAD
      path: kubernetes/applications/myapp
      helm:
        releaseName: myapp
        valueFiles:
          - $values/config/homelab.yaml # Global config
          - values.yaml # Chart defaults

    # 2. Reference to values repo
    - repoURL: https://github.com/YourUser/homelab.git
      targetRevision: HEAD
      ref: values

    # 3. Sealed secrets (raw manifests)
    - repoURL: https://github.com/YourUser/homelab.git
      targetRevision: HEAD
      path: kubernetes/applications/myapp/secrets
      directory:
        recurse: false
        include: "*.yaml"

  destination:
    server: https://kubernetes.default.svc
    namespace: myapp # Creates this namespace

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Step 4: Create Deployment Template

```yaml
# kubernetes/applications/myapp/templates/deployment.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: myapp
spec:
  replicas: {{ .Values.replicaCount | default 1 }}
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
    spec:
      containers:
        - name: myapp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          # Environment variables from secrets
          envFrom:
            - secretRef:
                name: myapp-secrets
                optional: true
          # Resource limits (recommended)
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          # Health checks
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          # Persistent storage (optional)
          {{- if .Values.persistence.enabled }}
          volumeMounts:
            - name: data
              mountPath: /data
          {{- end }}
      {{- if .Values.persistence.enabled }}
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: myapp-data
      {{- end }}
```

### Step 5: Create Service Template

```yaml
# kubernetes/applications/myapp/templates/service.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: { { .Release.Namespace } }
  labels:
    app.kubernetes.io/name: myapp
spec:
  type: { { .Values.service.type | default "ClusterIP" } }
  ports:
    - port: { { .Values.service.port } }
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: myapp
```

### Step 6: Create IngressRoute (Traefik)

```yaml
# kubernetes/applications/myapp/templates/ingressroute.yaml
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp
  namespace: {{ .Release.Namespace }}
  annotations:
    kubernetes.io/ingress.class: traefik
  labels:
    app.kubernetes.io/name: myapp
spec:
  entryPoints:
    - websecure  # HTTPS only
  routes:
    - match: Host(`myapp.{{ .Values.global.domain }}`)
      kind: Rule
      priority: 10
      {{- if .Values.auth_enabled }}
      # Protect with Authelia SSO
      middlewares:
        - name: authelia-forward-auth
          namespace: authelia
      {{- end }}
      services:
        - name: myapp
          port: {{ .Values.service.port }}
  tls:
    secretName: myapp-tls  # Created by Certificate below
```

### Step 7: Create Certificate (cert-manager)

```yaml
# kubernetes/applications/myapp/templates/certificate.yaml
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: { { .Release.Namespace } }
  labels:
    app.kubernetes.io/name: myapp
spec:
  secretName: myapp-tls
  issuerRef:
    name: { { .Values.global.cert_issuer | default "letsencrypt-prod" } }
    kind: ClusterIssuer
  dnsNames:
    - myapp.{{ .Values.global.domain }}
  privateKey:
    algorithm: ECDSA
    size: 256
```

### Step 8: Create PVC (if using storage)

```yaml
# kubernetes/applications/myapp/templates/pvc.yaml
{{- if .Values.persistence.enabled }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: myapp
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {{ .Values.persistence.storageClass | default "longhorn" }}
  resources:
    requests:
      storage: {{ .Values.persistence.size | default "5Gi" }}
{{- end }}
```

---

## Templates

### Using an External Helm Chart

If deploying an existing Helm chart (like Bitnami, etc.):

```yaml
# kubernetes/applications/myapp/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  sources:
    # 1. External Helm chart
    - repoURL: https://charts.bitnami.com/bitnami
      targetRevision: 1.2.3 # Chart version
      chart: myapp
      helm:
        releaseName: myapp
        valueFiles:
          - $values/kubernetes/applications/myapp/myapp-values.yaml

    # 2. Values from your repo
    - repoURL: https://github.com/YourUser/homelab.git
      targetRevision: HEAD
      ref: values

    # 3. Your custom ingress/cert resources
    - repoURL: https://github.com/YourUser/homelab.git
      targetRevision: HEAD
      path: kubernetes/applications/myapp
      helm:
        releaseName: myapp-ingress
        valueFiles:
          - $values/config/homelab.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Available Middlewares

Use these in your IngressRoute:

### Authelia SSO (Recommended for internal apps)

```yaml
middlewares:
  - name: authelia-forward-auth
    namespace: authelia
```

### Security Headers

```yaml
middlewares:
  - name: security-headers
    namespace: traefik
```

### Rate Limiting

```yaml
middlewares:
  - name: rate-limit
    namespace: traefik
```

### IP Whitelist (Local network only)

```yaml
middlewares:
  - name: ip-whitelist-local
    namespace: traefik
```

### Compression

```yaml
middlewares:
  - name: compress
    namespace: traefik
```

### Chain Multiple Middlewares

```yaml
middlewares:
  - name: authelia-forward-auth
    namespace: authelia
  - name: security-headers
    namespace: traefik
  - name: rate-limit
    namespace: traefik
```

---

## Storage Options

### Longhorn (Recommended for persistent data)

```yaml
persistence:
  storageClass: longhorn
  size: 10Gi
```

Features:

- Replicated across nodes (when multi-node)
- Snapshots and backups
- Volume expansion

### local-path (For ephemeral/cache data)

```yaml
persistence:
  storageClass: local-path
  size: 5Gi
```

Features:

- Fast local storage
- No replication
- Lost if node is rebuilt

---

## Secrets Management

### 1. Add Secret to config/secrets.yml

```yaml
# config/secrets.yml (gitignored)
secrets:
  # ... existing secrets ...

  - name: myapp-secrets
    namespace: myapp
    type: Opaque
    data:
      DATABASE_URL: "postgres://user:pass@host:5432/db"
      API_KEY: "your-secret-api-key"
    output_path: kubernetes/applications/myapp/secrets/myapp-secrets-sealed.yaml
```

### 2. Seal the Secrets

```bash
make seal-secrets
# Or: ansible-playbook ansible/playbooks/seal-secrets.yml
```

### 3. Reference in Deployment

```yaml
# In deployment.yaml
envFrom:
  - secretRef:
      name: myapp-secrets
```

Or individual keys:

```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: myapp-secrets
        key: DATABASE_URL
```

---

## Testing Locally

### 1. Render Templates Locally

```bash
cd kubernetes/applications/myapp
helm template myapp . -f ../../config/homelab.yaml
```

### 2. Validate YAML

```bash
helm lint .
kubectl apply --dry-run=client -f templates/
```

### 3. Check ArgoCD Status

```bash
# List all apps
kubectl get applications -n argocd

# Get app details
kubectl get application myapp -n argocd -o yaml

# Sync manually
argocd app sync myapp
```

---

## Troubleshooting

### Application Not Appearing in ArgoCD

1. Verify `application.yaml` exists in the correct path
2. Check root-app syncs your path:
   ```bash
   kubectl get application root-app -n argocd -o yaml
   ```

### Certificate Not Issued

```bash
# Check certificate status
kubectl get certificate -n myapp
kubectl describe certificate myapp-tls -n myapp

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check DNS is resolving
nslookup myapp.silverseekers.org
```

### IngressRoute Not Working

```bash
# Check Traefik sees the route
kubectl get ingressroute -n myapp

# Check Traefik logs
kubectl logs -n traefik deployment/traefik

# Verify service is reachable
kubectl port-forward -n myapp svc/myapp 8080:8080
curl http://localhost:8080
```

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n myapp
kubectl describe pod -n myapp <pod-name>

# Check logs
kubectl logs -n myapp <pod-name>

# Check events
kubectl get events -n myapp --sort-by='.lastTimestamp'
```

### Secret Not Found

```bash
# Check sealed secret exists
kubectl get sealedsecret -n myapp

# Check secret was created
kubectl get secret -n myapp

# Check sealed-secrets controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller
```

---

## Sync Wave Order

Control deployment order with annotations:

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "5"
```

**Current sync waves:**

- Wave 1: cert-manager
- Wave 2: Traefik
- Wave 3: Authelia, NetworkPolicies, ResourcePolicies
- Wave 4: Loki, Promtail, Garage, Velero, Cloudflared, External-DNS
- Wave 5: Monitoring, Applications

**Recommendation:** Use wave 5+ for user applications.

---

## Example: Adding a Simple Web App

Complete example for a static web app:

```bash
# Create structure
mkdir -p kubernetes/applications/mywebsite/{templates,secrets}

# Create files
cat > kubernetes/applications/mywebsite/Chart.yaml << 'EOF'
apiVersion: v2
name: mywebsite
description: My personal website
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF

cat > kubernetes/applications/mywebsite/values.yaml << 'EOF'
replicaCount: 1
image:
  repository: nginx
  tag: alpine
service:
  port: 80
auth_enabled: false
EOF

# Create deployment, service, ingressroute, certificate templates
# (use templates from above)

# Create application.yaml
# (use template from above)

# Commit and push
git add kubernetes/applications/mywebsite
git commit -m "Add mywebsite"
git push

# ArgoCD will automatically deploy it!
```

---

## See Also

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Traefik IngressRoute](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [cert-manager Certificates](https://cert-manager.io/docs/usage/certificate/)
- [Sealed Secrets](../kubernetes/services/sealed-secrets/README.md)
- [Authelia Configuration](../kubernetes/services/authelia/README.md)
