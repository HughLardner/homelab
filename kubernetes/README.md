# Kubernetes Manifests

This directory contains Kubernetes manifest files and Helm charts for deploying and managing services and applications on your K3s clusters.

## Configuration Architecture

All configuration is centralized in `config/homelab.yaml` - the **single source of truth**.

```
config/
├── homelab.yaml    # All non-secret configuration
└── secrets.yml     # Secrets (gitignored)
```

Services are packaged as **Helm charts** that read values from `config/homelab.yaml`:

```
kubernetes/services/<service>/
├── Chart.yaml          # Helm chart definition
├── values.yaml         # Default values (overridden by config)
├── <app>-values.yaml   # Helm values for upstream chart (if applicable)
└── templates/
    ├── certificate.yaml    # TLS certificate
    ├── ingressroute.yaml   # Traefik IngressRoute
    └── ...
```

## Directory Structure

```
kubernetes/
├── README.md                    # This file
├── applications/                # Applications managed by ArgoCD
│   ├── root-app.yaml            # App-of-Apps pattern
│   ├── monitoring/              # Victoria Metrics + Grafana (Helm chart)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   └── README.md
│   ├── authelia/                # ArgoCD Application for authelia
│   │   └── application.yaml
│   ├── argocd-ingress/          # ArgoCD Application for argocd
│   │   └── application.yaml
│   ├── traefik-ingress/         # ArgoCD Application for traefik
│   │   └── application.yaml
│   └── longhorn-ingress/        # ArgoCD Application for longhorn
│       └── application.yaml
└── services/                    # Infrastructure services (Helm charts)
    ├── metallb/                 # MetalLB LoadBalancer
    ├── longhorn/                # Distributed block storage (Helm chart)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    ├── cert-manager/            # TLS certificate automation
    ├── traefik/                 # Ingress controller (Helm chart)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    ├── argocd/                  # GitOps platform (Helm chart)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    ├── authelia/                # SSO/2FA authentication (Helm chart)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    └── sealed-secrets/          # Secret encryption for GitOps
```

## How Configuration Works

### Single Source of Truth

All services read configuration from `config/homelab.yaml`:

```yaml
# config/homelab.yaml
global:
  domain: silverseekers.org
  cert_issuer: letsencrypt-prod
  email: your@email.com

services:
  traefik:
    domain: traefik.silverseekers.org
    replicas: 2
  argocd:
    domain: argocd.silverseekers.org
  authelia:
    domain: auth.silverseekers.org
  grafana:
    domain: grafana.silverseekers.org
```

### Helm Charts Use Values from Config

Each service's Helm templates access values via `{{ .Values }}`:

```yaml
# kubernetes/services/authelia/templates/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: authelia-tls
spec:
  issuerRef:
    name: {{ .Values.services.authelia.cert_issuer | default .Values.global.cert_issuer }}
  dnsNames:
    - {{ .Values.services.authelia.domain }}
```

### Deployment Methods

All methods use the same configuration file:

**1. Helm directly:**
```bash
helm upgrade --install authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia --create-namespace
```

**2. Ansible (via kubernetes.core.helm):**
```yaml
- name: Deploy via Helm
  kubernetes.core.helm:
    name: authelia-ingress
    chart_ref: "{{ playbook_dir }}/../../kubernetes/services/authelia"
    values_files:
      - "{{ playbook_dir }}/../../config/homelab.yaml"
```

**3. ArgoCD (via multi-source Applications):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  sources:
    - repoURL: https://github.com/HughLardner/homelab.git
      path: kubernetes/services/authelia
      helm:
        valueFiles:
          - $values/config/homelab.yaml
    - repoURL: https://github.com/HughLardner/homelab.git
      ref: values
```

## Purpose and Philosophy

### Infrastructure Layer Separation

| Layer | Tool | Purpose | Location |
|-------|------|---------|----------|
| **Configuration** | YAML | Single source of truth | `config/` |
| **Infrastructure** | Terraform | VMs, networks, storage | `terraform/` |
| **Platform** | Ansible | K3s, OS config | `ansible/` |
| **Services** | Helm/GitOps | Networking, storage, ingress | `kubernetes/services/` |
| **Applications** | Helm/GitOps | Your workloads | `kubernetes/applications/` |

### Chart Co-location

Charts are **co-located with their service directories** rather than in a separate `charts/` folder:

```
kubernetes/services/authelia/    # Everything about authelia in one place
├── Chart.yaml                   # Helm chart metadata
├── values.yaml                  # Default values
├── authelia-values.yaml         # Upstream Helm chart values
├── templates/                   # Custom templates
│   ├── certificate.yaml
│   ├── ingressroute.yaml
│   └── middleware.yaml
├── secrets/                     # Sealed secrets
│   └── authelia-secrets-sealed.yaml
└── README.md                    # Service documentation
```

**Benefits:**
- Everything about a service in one directory
- Matches existing `kubernetes/services/` structure
- Easier to navigate and maintain
- No separate `charts/` directory to manage

## Deployment Commands

### Deploy Individual Service

```bash
# Via Helm directly
helm upgrade --install <service>-ingress ./kubernetes/services/<service> \
  -f ./config/homelab.yaml -n <namespace> --create-namespace

# Via Ansible
make <service>-install

# Examples
helm upgrade --install authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia --create-namespace

make traefik-install
make argocd-install
```

### Deploy All Services

```bash
# Full deployment (Terraform + Ansible + Services + Apps)
make deploy-all

# Just services
make deploy-services
```

### ArgoCD GitOps

Once ArgoCD is running, services sync automatically:

```bash
# Deploy root application (app-of-apps pattern)
make root-app-deploy

# Check application status
make apps-status

# List all applications
make apps-list
```

## Services

### Core Platform ✅ (Helm Charts)

Infrastructure services deployed as Helm charts:

| Service | Helm Chart | Namespace | Description |
|---------|------------|-----------|-------------|
| **MetalLB** | Kustomize | metallb-system | LoadBalancer IP assignment |
| **Longhorn** | `services/longhorn/` | longhorn-system | Distributed block storage |
| **Cert-Manager** | Upstream | cert-manager | TLS certificate automation |
| **Traefik** | `services/traefik/` | traefik | Ingress controller |
| **ArgoCD** | `services/argocd/` | argocd | GitOps platform |
| **Sealed Secrets** | Upstream | sealed-secrets | Secret encryption |
| **Authelia** | `services/authelia/` | authelia | SSO/2FA authentication |

### Applications ✅ (ArgoCD GitOps)

Applications managed via ArgoCD:

| Application | Helm Chart | Namespace | Description |
|-------------|------------|-----------|-------------|
| **Monitoring** | `applications/monitoring/` | monitoring | Victoria Metrics + Grafana |

## View Service Status

```bash
# List all deployments in a namespace
kubectl get all -n <namespace>

# View pods
kubectl get pods -n authelia
kubectl get pods -n traefik

# View services with external IPs
kubectl get svc --all-namespaces | grep LoadBalancer

# Check certificates
kubectl get certificates -A
```

## Configuration Changes

To change any service configuration:

1. Edit `config/homelab.yaml`:
```yaml
services:
  authelia:
    domain: auth.example.org  # Changed domain
    cert_issuer: letsencrypt-staging  # Override global cert issuer
```

2. Re-deploy:
```bash
# Via Helm
helm upgrade authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia

# Via Ansible
make authelia-install

# Via ArgoCD (automatic on git push)
git commit -am "Update authelia domain"
git push
```

## Best Practices

### 1. Single Source of Truth

All configuration in `config/homelab.yaml`:
- ✅ One file to edit for any change
- ✅ Consistent values across all deployment methods
- ✅ No duplication between Terraform, Ansible, and Helm

### 2. Use Helm Charts

Services are packaged as Helm charts:
- ✅ Native templating (no Jinja2/ArgoCD conflicts)
- ✅ Works with Ansible, ArgoCD, and kubectl
- ✅ Consistent deployment experience

### 3. Version Control Everything

All manifests should be:
- ✅ Committed to git
- ✅ Reviewed before applying
- ✅ Secrets encrypted with Sealed Secrets

### 4. Document Configuration

Each service should have:
- `README.md` - Usage and configuration
- Comments in YAML - Explain non-obvious settings
- Examples - Common use cases

## Integration with Infrastructure

### Configuration Flow

```
┌────────────────────────────────────────────────────────────────┐
│ config/homelab.yaml (Single Source of Truth)                   │
└────────────────────────────────────────────────────────────────┘
           ↓                    ↓                    ↓
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │  Terraform   │    │   Ansible    │    │   ArgoCD     │
    │ (yamldecode) │    │ (vars_files) │    │ (valueFiles) │
    └──────────────┘    └──────────────┘    └──────────────┘
           ↓                    ↓                    ↓
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │  Provisions  │    │   Deploys    │    │   Syncs      │
    │     VMs      │    │ Helm Charts  │    │ Helm Charts  │
    └──────────────┘    └──────────────┘    └──────────────┘
```

### Dynamic vs Static Configuration

**Static** (in `config/homelab.yaml`):
- Service domains
- Cert issuers
- Replicas
- Resource limits
- Everything else

**Dynamic** (from Terraform):
- Node IPs (written to inventory)
- Infrastructure-specific settings

## Future Additions

### Networking
- [ ] **external-dns** - Automatic DNS record creation (Cloudflare provider)

### Storage
- [ ] **minio** - S3-compatible object storage
- [ ] **velero** - Backup and restore

### Observability
- [ ] **loki** - Log aggregation
- [ ] **tempo** - Distributed tracing

### Security
- [ ] **vault** - Secret management
- [ ] **falco** - Runtime security

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
