# Homelab Infrastructure

Production-ready Kubernetes (K3s) platform on Proxmox VE with complete GitOps workflow and monitoring.

## Features

### Infrastructure (Terraform)

- **Single-node deployment** optimized for low-power hardware (12GB RAM)
- **Automated VM provisioning** on Proxmox VE
- **Configuration from single source** - reads from `config/homelab.yaml`
- **Cloud-init configuration** for consistent node setup

### Bootstrap Layer (Ansible - 4 Services)

Essential foundation that must exist before ArgoCD can work:

- **MetalLB** LoadBalancer (192.168.10.150-165)
- **Longhorn** distributed block storage (1 replica, 200GB persistent LV on Proxmox)
- **Sealed Secrets** encrypted secrets for GitOps workflow
- **ArgoCD** GitOps continuous delivery platform

### Platform Services (ArgoCD GitOps)

Deployed automatically via ArgoCD sync waves:

- **Cert-Manager** (Wave 1) - Automated TLS certificates via Let's Encrypt + Cloudflare DNS
- **Traefik** (Wave 2) - Ingress controller with HTTPS
- **Authelia** (Wave 3) - SSO/2FA authentication portal
- **NetworkPolicies** (Wave 3) - Namespace network isolation
- **ResourcePolicies** (Wave 3) - LimitRange and ResourceQuota
- **Loki + Promtail** (Wave 4) - Centralized log aggregation and collection
- **Garage** (Wave 4) - S3-compatible object storage (lightweight MinIO replacement)
- **Velero** (Wave 4) - Kubernetes backup and restore (to Garage S3)
- **Cloudflared** (Wave 4) - Cloudflare Tunnel (only `fallandrise.silverseekers.org` is public)
- **External-DNS** (Wave 4) - Automatic Cloudflare DNS record management
- **Intel Device Plugins** (Wave 4) - GPU passthrough for media transcoding

### Applications (ArgoCD GitOps)

- **Monitoring Stack** (Wave 5) - Victoria Metrics + Grafana
  - VMSingle time-series database (lightweight Prometheus alternative)
  - VMAgent metrics scraper, VMAlert + VMAlertmanager for alerting
  - Grafana with Loki datasource for logs + dashboards
- **Home Assistant** - Home automation (with OIDC, HACS auto-setup)
- **Homepage** - Homelab dashboard with Proxmox/cluster integration
- **Node-RED** - IoT flow automation (OIDC protected)
- **Zigbee2MQTT** - Zigbee coordinator via SMLIGHT SLZB TCP adapter
- **Mosquitto** - MQTT broker for IoT devices
- **Pi-hole** - DNS ad-blocker (dedicated IP: 192.168.10.152)
- **Plex** - Media server with Intel GPU transcoding (on-demand via HA toggle)
- **Filebrowser** - Web file manager for Plex media uploads
- **Forgejo** - Self-hosted Git server
- **Quartz** - Digital garden at `fallandrise.silverseekers.org` (publicly accessible via Cloudflare Tunnel)
- **Obsidian LiveSync** - CouchDB backend for Obsidian sync across devices
- **Headlamp** - Kubernetes web UI

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
make deploy-all        # Deploy everything (infra + platform + bootstrap + services)

# Stage-by-stage deployment
make deploy-infra      # 1. Terraform VMs only
make deploy-platform   # 2. Add K3s cluster
make deploy-bootstrap  # 3. Deploy minimal bootstrap (MetalLB, Longhorn, Sealed Secrets, ArgoCD)
make deploy-services   # 4. Deploy all services via ArgoCD
```

### Manual Step-by-Step

```bash
# 1. Infrastructure
cd terraform && terraform init
terraform workspace select k3s
terraform apply && cd ..

# 2. Platform
make k3s-install

# 3. Bootstrap (Ansible - 4 services)
make metallb-install
make longhorn-install
make sealed-secrets-install
make argocd-install

# 4. Access ArgoCD via LoadBalancer IP
ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open https://$ARGOCD_IP

# 5. Deploy all services via ArgoCD
kubectl apply -f kubernetes/applications/root-app.yaml
# ArgoCD deploys everything else in sync-wave order:
#   Wave 1: Cert-Manager
#   Wave 2: Traefik
#   Wave 3: Authelia, NetworkPolicies, LimitRanges
#   Wave 4: Loki, Promtail, Garage, Velero, Cloudflared, External-DNS
#   Wave 5: Monitoring
```

## Available Make Commands

```bash
# Full Stack Deployment (Recommended)
make deploy-all        # Deploy everything (infra + platform + bootstrap + services)
make deploy-bootstrap  # Deploy minimal bootstrap (MetalLB, Longhorn, Sealed Secrets, ArgoCD)
make deploy-services   # Deploy all services via ArgoCD (after bootstrap)
make deploy-platform   # Deploy infra + K3s cluster
make deploy-infra      # Deploy Terraform VMs only
make deploy            # Alias for deploy-all

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
- [ADDING_APPLICATIONS.md](docs/ADDING_APPLICATIONS.md) - How to add new applications to the cluster

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
- [Garage README](kubernetes/services/garage/README.md) - S3-compatible object storage (replaces MinIO)
- [Velero README](kubernetes/services/velero/README.md) - Kubernetes backup and restore
- [External-DNS README](kubernetes/services/external-dns/README.md) - Cloudflare DNS automation
- [Loki README](kubernetes/services/loki/README.md) - Log aggregation
- [Cloudflared README](kubernetes/services/cloudflared/README.md) - Cloudflare tunnel

### Monitoring & Observability

- [Monitoring README](kubernetes/applications/monitoring/README.md) - Victoria Metrics + Grafana stack
- [Grafana MCP](docs/GRAFANA_MCP.md) - AI assistant integration with Grafana

### Operations

- [Persistent Storage](docs/PERSISTENT_STORAGE.md) - Proxmox LV architecture for Longhorn
- [Pre-Proxmox 9 Backup](docs/PRE_PROXMOX9_BACKUP.md) - Backup checklist (upgrade reference)
- [Runbooks](docs/runbooks/) - Incident recovery procedures

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
│ Bootstrap Services (Ansible)                            │
│  • MetalLB (LoadBalancer: 192.168.10.150-165)           │
│  • Longhorn (Storage: 200GB persistent LV)              │
│  • Sealed Secrets (Secret Encryption)                   │
│  • ArgoCD (GitOps)                                      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Platform Services (ArgoCD Wave 1–4)                     │
│  • Cert-Manager · Traefik · Authelia                    │
│  • Loki · Promtail · Garage (S3) · Velero               │
│  • Cloudflared · External-DNS · Intel Device Plugins    │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ Applications (ArgoCD Wave 5+)                           │
│  • Monitoring (Victoria Metrics + Grafana)              │
│  • Home Assistant · Node-RED · Zigbee2MQTT · Mosquitto  │
│  • Plex · Filebrowser · Pi-hole                         │
│  • Forgejo · Quartz · Obsidian LiveSync · Headlamp      │
│  • Homepage                                              │
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

### Infrastructure & Platform

| Service               | URL                                    | Auth                  |
| --------------------- | -------------------------------------- | --------------------- |
| **Traefik Dashboard** | https://traefik.silverseekers.org      | Authelia SSO          |
| **ArgoCD**            | https://argocd.silverseekers.org       | Authelia OIDC         |
| **Authelia**          | https://auth.silverseekers.org         | (configured users)    |
| **Grafana**           | https://grafana.silverseekers.org      | admin / (from config) |
| **Longhorn UI**       | https://longhorn.silverseekers.org     | Authelia SSO          |
| **Headlamp**          | https://headlamp.silverseekers.org     | Authelia SSO          |

### Applications

| Service               | URL                                    | Auth                  |
| --------------------- | -------------------------------------- | --------------------- |
| **Homepage**          | https://home.silverseekers.org         | Authelia SSO          |
| **Home Assistant**    | https://hass.silverseekers.org         | Authelia OIDC         |
| **Node-RED**          | https://node-red.silverseekers.org     | Authelia OIDC         |
| **Zigbee2MQTT**       | https://zigbee2mqtt.silverseekers.org  | Authelia SSO          |
| **Pi-hole**           | https://pihole.silverseekers.org       | Authelia SSO          |
| **Plex**              | https://plex.silverseekers.org         | Plex account          |
| **Filebrowser**       | https://files.silverseekers.org        | Authelia SSO          |
| **Forgejo**           | https://forgejo.silverseekers.org      | Forgejo accounts      |
| **Quartz**            | https://fallandrise.silverseekers.org  | Public (via Tunnel)   |
| **Obsidian LiveSync** | https://obsidian.silverseekers.org     | CouchDB auth          |
| **Garage S3**         | https://s3.silverseekers.org           | S3 credentials        |

## Network Configuration

- **Cluster Network**: 192.168.10.0/24
- **Node IP**: 192.168.10.20 (single-node cluster)
- **kube-vip (K8s API)**: 192.168.10.15
- **MetalLB Pool**: 192.168.10.150-165 (/28 range)
- **Traefik LoadBalancer**: 192.168.10.150

### DNS Configuration

All internal services are accessed through Traefik at `192.168.10.150`.

**Automatic DNS (External-DNS + Cloudflare):**  
External-DNS manages Cloudflare DNS records automatically. When a service is deployed with the correct annotations, DNS records are created/updated automatically.

**Local DNS (UniFi Gateway fallback):**  
For local resolution without hitting Cloudflare, configure your UniFi Gateway with a wildcard DNS entry:

```
Type: A Record
Name: *.silverseekers.org
IP: 192.168.10.150
```

**Pi-hole:**  
Pi-hole runs at a dedicated MetalLB IP (`192.168.10.152`) and can serve as a local DNS/ad-blocker for the network.

**Public Access:**  
Only `fallandrise.silverseekers.org` (Quartz digital garden) is publicly accessible, via Cloudflare Tunnel (`cloudflared`). All other services are internal-only.

**Architecture:**

```
Browser → UniFi DNS → Traefik (192.168.10.150) → Backend Service
                         ↓
                    Host() routing
                    /     |     \
               ArgoCD  Grafana  Longhorn
```
