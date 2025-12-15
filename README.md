# Homelab Infrastructure

Production-ready Kubernetes (K3s) platform on Proxmox VE with complete GitOps workflow and monitoring.

## Features

### Infrastructure (Terraform)

- **Single-node deployment** optimized for low-power hardware (12GB RAM)
- **Automated VM provisioning** on Proxmox VE
- **Configuration from single source** - reads from `config/homelab.yaml`
- **Cloud-init configuration** for consistent node setup

### Platform Services (Ansible)

- **K3s cluster** single-node deployment (can scale to HA with 3 control plane nodes)
- **MetalLB** LoadBalancer (192.168.10.150-165)
- **Longhorn** distributed block storage (1 replica for single node)
- **Cert-Manager** automated TLS certificates via Let's Encrypt + Cloudflare DNS
- **Traefik** ingress controller with HTTPS
- **ArgoCD** GitOps continuous delivery platform
- **Sealed Secrets** encrypted secrets for GitOps workflow
- **Authelia** SSO/2FA authentication portal

### Applications (ArgoCD/GitOps)

- **Monitoring Stack** (Victoria Metrics + Grafana)
  - Grafana metrics visualization (https://grafana.silverseekers.org)
  - VMSingle time-series database (lightweight Prometheus alternative)
  - VMAgent metrics scraper
  - VMAlert + VMAlertmanager for alerting
  - Node exporters on all cluster nodes
  - Kube-state-metrics for cluster state monitoring

## Configuration Architecture

All configuration is centralized in `config/homelab.yaml` - the **single source of truth**.

```
config/
├── homelab.yaml    # All non-secret configuration
└── secrets.yml     # Secrets (gitignored)
```

### How It Works

```
config/homelab.yaml (Single Source of Truth)
       │
       ├─► Terraform (yamldecode)
       ├─► Ansible (vars_files)
       ├─► Helm Charts (values)
       └─► ArgoCD (valueFiles)
```

### Editing Configuration

1. Edit `config/homelab.yaml` for any configuration changes
2. Changes automatically propagate to all tools:
   - Terraform reads via `yamldecode()`
   - Ansible playbooks load via `vars_files`
   - ArgoCD applications use Helm with `valueFiles`

### Example Configuration

```yaml
# config/homelab.yaml
global:
  domain: silverseekers.org
  cert_issuer: letsencrypt-prod
  email: your@email.com

services:
  traefik:
    domain: traefik.example.org
    replicas: 2
  argocd:
    domain: argocd.example.org
  grafana:
    domain: grafana.example.org
  # ... more services
```

## Quick Start

### One-Command Deployment

```bash
# 1. Configure your homelab
cp config/homelab.yaml.example config/homelab.yaml
vim config/homelab.yaml  # Edit your configuration

# 2. Set up secrets
cp secrets.example.yml config/secrets.yml
vim config/secrets.yml  # Add your secrets

# 3. Deploy everything
cd terraform
terraform init
terraform workspace select k3s
cd ..
make deploy-all

# Access your cluster
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
kubectl get pods -A
```

### Deployment Options

```bash
# Full stack deployment (recommended)
make deploy-all        # Deploy everything (infra + platform + services + apps)

# Stage-by-stage deployment
make deploy-infra      # 1. Terraform VMs only
make deploy-platform   # 2. Add K3s cluster
make deploy-services   # 3. Add all core services
make deploy-apps       # 4. Add monitoring applications

# Individual service deployment
helm upgrade --install authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia --create-namespace
```

### Manual Step-by-Step

```bash
# 1. Infrastructure
cd terraform && terraform init
terraform workspace select k3s
terraform apply && cd ..

# 2. Platform
make k3s-install

# 3. Core Services
make metallb-install longhorn-install cert-manager-install
make traefik-install argocd-install sealed-secrets-install

# 4. Applications
make monitoring-secrets monitoring-install
```

## Available Make Commands

```bash
# Full Stack Deployment (Recommended)
make deploy-all        # Deploy everything (infra + platform + services + apps)
make deploy-services   # Deploy infra + platform + all core services
make deploy-platform   # Deploy infra + K3s cluster
make deploy-infra      # Deploy Terraform VMs only
make deploy-apps       # Deploy applications only
make deploy            # Alias for deploy-services

# Infrastructure (Terraform)
make init              # Initialize Terraform
make plan              # Plan infrastructure changes
make apply             # Apply infrastructure changes
make destroy           # Destroy infrastructure

# Cluster Platform (Ansible)
make k3s-install       # Install K3s cluster with HA etcd
make k3s-status        # Check cluster status
make metallb-install   # Install MetalLB LoadBalancer
make longhorn-install  # Install Longhorn storage
make longhorn-ui       # Open Longhorn UI

# Core Services (Ansible)
make cert-manager-install  # Install cert-manager for TLS
make cert-manager-status   # Check cert-manager status
make traefik-install       # Install Traefik ingress
make traefik-status        # Check Traefik status
make traefik-dashboard     # Open Traefik dashboard
make argocd-install        # Install ArgoCD GitOps
make argocd-ui             # Open ArgoCD UI
make argocd-password       # Get ArgoCD admin password
make sealed-secrets-install # Install Sealed Secrets
make sealed-secrets-status  # Check Sealed Secrets status
make seal-secrets          # Encrypt secrets from config/secrets.yml

# Applications (ArgoCD/GitOps)
make monitoring-secrets    # Create monitoring secrets (required first)
make monitoring-deploy     # Deploy monitoring via ArgoCD (GitOps)
make monitoring-status     # Check monitoring stack status
make grafana-ui            # Open Grafana dashboard
make vmsingle-ui           # Port-forward Victoria Metrics UI

# GitOps (ArgoCD)
make root-app-deploy   # Deploy App-of-Apps pattern
make apps-list         # List all ArgoCD applications
make apps-status       # Show application sync status

# Utilities
make ping              # Test node connectivity
make ssh-node          # SSH to the cluster node
make workspace-list    # List Terraform workspaces
make help              # Show all commands
```

## Documentation

### Planning & Architecture

- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) - Complete implementation guide with phases
- [CLAUDE.md](CLAUDE.md) - Architecture and development guide for AI assistants
- [SECRETS.md](SECRETS.md) - Secrets management workflow with Sealed Secrets

### Infrastructure & Platform

- [Terraform README](terraform/README.md) - Infrastructure provisioning on Proxmox VE
- [Ansible README](ansible/README.md) - Cluster and services deployment
- [Kubernetes README](kubernetes/README.md) - Kubernetes resources and GitOps structure

### Core Services

- [MetalLB README](kubernetes/services/metallb/README.md) - LoadBalancer configuration
- [Longhorn README](kubernetes/services/longhorn/README.md) - Distributed storage
- [Cert-Manager README](kubernetes/services/cert-manager/README.md) - TLS certificate automation
- [Traefik README](kubernetes/services/traefik/README.md) - Ingress controller
- [ArgoCD README](kubernetes/services/argocd/README.md) - GitOps platform
- [Sealed Secrets README](kubernetes/services/sealed-secrets/README.md) - Secret encryption
- [Authelia README](kubernetes/services/authelia/README.md) - SSO/2FA authentication

### Monitoring

- [Monitoring README](kubernetes/applications/monitoring/README.md) - Prometheus + Grafana stack

### AI Integration

- [Grafana MCP](docs/GRAFANA_MCP.md) - AI assistant integration with Grafana

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Configuration (Single Source of Truth)                  │
│  • config/homelab.yaml - All service configuration      │
│  • config/secrets.yml  - Secrets (gitignored)           │
└─────────────────────────────────────────────────────────┘
           ↓                    ↓                    ↓
    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
    │  Terraform   │    │   Ansible    │    │   ArgoCD     │
    │ (yamldecode) │    │ (vars_files) │    │ (valueFiles) │
    └──────────────┘    └──────────────┘    └──────────────┘
           ↓                    ↓                    ↓
┌─────────────────────────────────────────────────────────┐
│ Proxmox VE Infrastructure                               │
│  • 1 VM (192.168.10.20) - 12GB RAM, 100GB               │
│  • Cloud-init configuration                             │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ K3s Cluster                                             │
│  • Single-node cluster (scalable to HA)                 │
│  • MetalLB: 192.168.10.150-165                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Core Platform Services                                  │
│  • Longhorn (Storage)                                   │
│  • Cert-Manager (TLS)                                   │
│  • Traefik (Ingress @ 192.168.10.150)                   │
│  • ArgoCD (GitOps)                                      │
│  • Sealed Secrets (Secret Encryption)                   │
│  • Authelia (SSO/2FA)                                   │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Applications (ArgoCD/GitOps via Helm Charts)            │
│  • Each service is a Helm chart in kubernetes/services/ │
│  • ArgoCD deploys with config/homelab.yaml as values    │
│  • Monitoring Stack (Victoria Metrics + Grafana)        │
└─────────────────────────────────────────────────────────┘
```

## Service Helm Charts

Each service is packaged as a Helm chart that can be deployed via ArgoCD, Ansible, or kubectl:

```
kubernetes/services/
├── authelia/           # SSO Authentication
│   ├── Chart.yaml
│   ├── values.yaml     # Default values
│   ├── authelia-values.yaml  # Main app Helm values
│   └── templates/
├── argocd/             # GitOps Platform
├── traefik/            # Ingress Controller
├── longhorn/           # Distributed Storage
└── ...
```

### Deploying a Service

```bash
# Via Helm directly
helm upgrade --install authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia --create-namespace

# Via ArgoCD (automatic)
# Services are deployed automatically when root-app syncs

# Via Ansible
ansible-playbook ansible/playbooks/authelia.yml
```

## Access Points

| Service               | URL                                | Credentials              |
| --------------------- | ---------------------------------- | ------------------------ |
| **Traefik Dashboard** | https://traefik.silverseekers.org  | admin / (from config)    |
| **ArgoCD**            | https://argocd.silverseekers.org   | admin / (via secrets)    |
| **Grafana**           | https://grafana.silverseekers.org  | admin / (from config)    |
| **Authelia**          | https://auth.silverseekers.org     | (configured users)       |
| **Longhorn UI**       | https://longhorn.silverseekers.org | N/A                      |

## Network Configuration

- **Cluster Network**: 192.168.10.0/24
- **Node IP**: 192.168.10.20 (single-node cluster)
- **kube-vip (K8s API)**: 192.168.10.15
- **MetalLB Pool**: 192.168.10.150-165 (/28 range)
- **Traefik LoadBalancer**: 192.168.10.150

### DNS Configuration (UniFi Gateway)

All services are accessed through Traefik at `192.168.10.150`. Configure your UniFi Gateway with a wildcard DNS entry:

**UniFi Network → Settings → DNS:**

```
Type: A Record
Name: *.silverseekers.org
IP: 192.168.10.150
```

If your UniFi version doesn't support wildcard DNS, add individual entries:

- `argocd.silverseekers.org` → `192.168.10.150`
- `traefik.silverseekers.org` → `192.168.10.150`
- `grafana.silverseekers.org` → `192.168.10.150`
- `longhorn.silverseekers.org` → `192.168.10.150`
- `auth.silverseekers.org` → `192.168.10.150`

**Architecture:**

```
Browser → UniFi DNS → Traefik (192.168.10.150) → Backend Service
                         ↓
                    Host() routing
                    /     |     \
               ArgoCD  Grafana  Longhorn
```
