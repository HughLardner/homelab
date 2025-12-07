# Homelab Infrastructure

Terraform + Ansible automation for deploying Kubernetes (K3s) clusters on Proxmox VE with MetalLB LoadBalancer support.

## Features

- **Multi-cluster management** via Terraform workspaces
- **Automated K3s deployment** with HA embedded etcd
- **MetalLB LoadBalancer** with configurable IP pools
- **Firewall integration** with Proxmox VE firewall
- **VLAN support** with UniFi controller integration
- **Dynamic inventory generation** from Terraform state

## Quick Start

```bash
# Initialize and deploy infrastructure
cd terraform
terraform init
terraform workspace select k3s  # or alpha, beta, gamma
terraform apply

# Deploy K3s cluster
cd ..
make k3s-install

# Install MetalLB for LoadBalancer services
make metallb-install

# Access your cluster
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
```

## Available Make Commands

```bash
# Infrastructure
make init              # Initialize Terraform
make plan              # Plan infrastructure changes
make apply             # Apply infrastructure changes
make destroy           # Destroy infrastructure

# K3s Cluster
make inventory         # Generate Ansible inventory
make k3s-install       # Install K3s cluster
make k3s-status        # Check cluster status
make k3s-destroy       # Uninstall K3s

# Networking
make metallb-install   # Install MetalLB LoadBalancer
make metallb-test      # Install with test nginx LoadBalancer

# Utilities
make ping              # Test node connectivity
make ssh-node1         # SSH to first node
make workspace-list    # List Terraform workspaces
make help              # Show all commands
```

## Documentation

- [Terraform README](terraform/README.md) - Infrastructure provisioning
- [Ansible README](ansible/README.md) - K3s and MetalLB deployment
- [CLAUDE.md](CLAUDE.md) - Architecture and development guide