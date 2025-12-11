# Homelab Infrastructure

Production-ready Kubernetes (K3s) platform on Proxmox VE with complete GitOps workflow and monitoring.

## Features

### Infrastructure (Terraform)

- **Multi-cluster management** via Terraform workspaces
- **Automated VM provisioning** on Proxmox VE
- **Firewall integration** with automated IPSet/security groups
- **VLAN support** with UniFi controller integration
- **Dynamic inventory generation** for Ansible

### Platform Services (Ansible)

- **K3s cluster** with HA embedded etcd (3 control plane nodes)
- **MetalLB** LoadBalancer (192.168.10.150-159)
- **Longhorn** distributed block storage
- **Cert-Manager** automated TLS certificates via Let's Encrypt
- **Traefik** ingress controller with HTTPS
- **ArgoCD** GitOps continuous delivery platform
- **Sealed Secrets** encrypted secrets for GitOps workflow

### Applications (ArgoCD/GitOps)

- **Monitoring Stack** (Prometheus + Grafana)
  - Grafana metrics visualization (https://grafana.silverseekers.org)
  - Prometheus metrics collection and alerting
  - Node exporters on all cluster nodes
  - Kube-state-metrics for cluster state monitoring
- **Kured** automated node reboots during maintenance window (04:00-08:00 UTC)

## Quick Start

### One-Command Deployment

```bash
# Deploy everything from scratch (recommended)
cd terraform
terraform init
terraform workspace select k3s  # or alpha, beta, gamma
cd ..
make deploy-all

# Or deploy in stages
make deploy-infra      # 1. Terraform VMs only
make deploy-platform   # 2. Add K3s cluster
make deploy-services   # 3. Add all core services
make deploy-apps       # 4. Add monitoring applications

# Access your cluster
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
kubectl get pods -A
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
make seal-secrets          # Encrypt secrets from secrets.yml

# Applications (ArgoCD/GitOps)
make monitoring-secrets    # Create monitoring secrets (required first)
make monitoring-deploy     # Deploy monitoring via ArgoCD (GitOps)
make monitoring-status     # Check monitoring stack status
make grafana-ui            # Open Grafana dashboard
make kured-deploy          # Deploy Kured via ArgoCD (automated node reboots)
make kured-status          # Check Kured status
make kured-logs            # View Kured logs

# GitOps (ArgoCD)
make root-app-deploy   # Deploy App-of-Apps pattern
make apps-list         # List all ArgoCD applications
make apps-status       # Show application sync status

# Utilities
make ping              # Test node connectivity
make ssh-node1         # SSH to node 1
make ssh-node2         # SSH to node 2
make ssh-node3         # SSH to node 3
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
- [Kured README](kubernetes/services/kured/README.md) - Automated node reboots

### Monitoring

- [Monitoring README](kubernetes/applications/monitoring/README.md) - Prometheus + Grafana stack

### AI Integration

- [Grafana MCP](docs/GRAFANA_MCP.md) - AI assistant integration with Grafana

## Architecture

```
┌─────────────────────────────────────────────┐
│ Proxmox VE Infrastructure (Terraform)       │
│  • 3 VMs (192.168.10.20-22)                 │
│  • VLAN + Firewall configuration            │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│ K3s Cluster (Ansible)                       │
│  • 3 control plane nodes with HA etcd       │
│  • MetalLB: 192.168.10.150-159              │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│ Core Platform Services (Ansible)            │
│  • Longhorn (Storage)                       │
│  • Cert-Manager (TLS)                       │
│  • Traefik (Ingress @ 192.168.10.145)       │
│  • ArgoCD (GitOps)                          │
│  • Sealed Secrets (Secret Encryption)       │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│ Applications (ArgoCD/GitOps)                │
│  • Monitoring Stack (Prometheus + Grafana)  │
│    - Grafana: https://grafana.silverseekers.org
│    - Prometheus + Alertmanager              │
│  • Kured (Automated Node Reboots)           │
│  • Your Applications                        │
│    - Deployed via GitOps workflow           │
│    - Secrets encrypted with Sealed Secrets  │
└─────────────────────────────────────────────┘
```

## Access Points

| Service               | URL                               | Credentials              |
| --------------------- | --------------------------------- | ------------------------ |
| **Traefik Dashboard** | https://traefik.silverseekers.org | admin / (from Terraform) |
| **ArgoCD**            | https://argocd.silverseekers.org  | admin / (via secrets)    |
| **Grafana**           | https://grafana.silverseekers.org | admin / (from Terraform) |
| **Longhorn UI**       | Port-forward or LoadBalancer      | N/A                      |

## Network Configuration

- **Cluster Network**: 192.168.10.0/24
- **Node IPs**: 192.168.10.20-22
- **kube-vip (K8s API)**: 192.168.10.15
- **MetalLB Pool**: 192.168.10.145-161
- **Traefik LoadBalancer**: 192.168.10.145

### DNS Configuration (UniFi Gateway)

All services are accessed through Traefik at `192.168.10.145`. Configure your UniFi Gateway with a wildcard DNS entry:

**UniFi Network → Settings → DNS:**

```
Type: A Record
Name: *.silverseekers.org
IP: 192.168.10.145
```

If your UniFi version doesn't support wildcard DNS, add individual entries:

- `argocd.silverseekers.org` → `192.168.10.145`
- `traefik.silverseekers.org` → `192.168.10.145`
- `grafana.silverseekers.org` → `192.168.10.145`
- `longhorn.silverseekers.org` → `192.168.10.145`

**Architecture:**

```
Browser → UniFi DNS → Traefik (192.168.10.145) → Backend Service
                         ↓
                    Host() routing
                    /     |     \
               ArgoCD  Grafana  Longhorn
```
