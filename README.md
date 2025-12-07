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

### Monitoring (ArgoCD/Helm)
- **Grafana** metrics visualization (https://grafana.silverseekers.org)
- **Prometheus** metrics collection and alerting
- **Node exporters** on all cluster nodes
- **Kube-state-metrics** for cluster state monitoring

## Quick Start

```bash
# 1. Initialize and deploy infrastructure
cd terraform
terraform init
terraform workspace select k3s  # or alpha, beta, gamma
terraform apply

# 2. Deploy K3s cluster and core services
cd ..
make k3s-install         # K3s with HA etcd
make metallb-install     # LoadBalancer support
make longhorn-install    # Distributed storage
make cert-manager-install # TLS certificates
make traefik-install     # Ingress controller
make argocd-install      # GitOps platform

# 3. Deploy monitoring (requires secrets first)
make monitoring-secrets  # Create Grafana credentials
make monitoring-install  # Deploy Prometheus + Grafana

# 4. Access your cluster
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
kubectl get pods -A
```

## Available Make Commands

```bash
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

# Monitoring (ArgoCD/Ansible)
make monitoring-secrets    # Create monitoring secrets (required first)
make monitoring-deploy     # Deploy via ArgoCD (GitOps)
make monitoring-install    # Deploy via Ansible (legacy)
make monitoring-status     # Check monitoring stack status
make grafana-ui            # Open Grafana dashboard

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

### Monitoring
- [Monitoring README](kubernetes/applications/monitoring/README.md) - Prometheus + Grafana stack

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
│  • Traefik (Ingress @ 192.168.10.146)       │
│  • ArgoCD (GitOps)                          │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│ Monitoring Stack (ArgoCD/Helm)              │
│  • Grafana: https://grafana.silverseekers.org│
│  • Prometheus + Alertmanager                │
└─────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│ Your Applications (ArgoCD)                  │
│  • Deployed via GitOps workflow             │
└─────────────────────────────────────────────┘
```

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| **Traefik Dashboard** | https://traefik.silverseekers.org | admin / (from Terraform) |
| **ArgoCD** | https://argocd.silverseekers.org | admin / (via secrets) |
| **Grafana** | https://grafana.silverseekers.org | admin / (from Terraform) |
| **Longhorn UI** | Port-forward or LoadBalancer | N/A |

## Network Configuration

- **Cluster Network**: 192.168.10.0/24
- **Node IPs**: 192.168.10.20-22
- **MetalLB Pool**: 192.168.10.150-159
- **Traefik LoadBalancer**: 192.168.10.146
- **DNS**: `*.silverseekers.org` → 192.168.10.146