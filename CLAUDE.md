# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This homelab infrastructure uses **Terraform workspaces** to manage multiple Kubernetes clusters on Proxmox VE. Each workspace represents a distinct cluster (k3s, alpha, beta, gamma) with its own network configuration, VM specifications, and optional features like VLANs, firewalls, and high availability.

## Key Architecture Concepts

### Workspace-Based Cluster Management

- Terraform workspaces are the primary mechanism for managing different clusters
- The active workspace determines which cluster configuration from `var.clusters` is used
- `local.cluster_config = var.clusters[terraform.workspace]` (locals.tf:47)
- `local.nodes` is filtered to only include nodes from the current workspace (locals.tf:53)

### Node Class System

Each cluster defines multiple "node classes" (e.g., controlplane, general, etcd, gpu) with their own specs:
- CPU cores/sockets, memory, disk configurations
- Starting IP offset (combined with cluster_id to generate unique IPs)
- Kubernetes labels and taints
- Device pass-through (USB/PCI)
- Allowed Proxmox nodes for placement

The `local.all_nodes` local variable flattens all clusters and node classes into individual VM definitions (locals.tf:2-45).

### VM ID and IP Generation

- VM IDs are generated as: `"${cluster.cluster_id}${specs.start_ip + i}"` (locals.tf:10)
- IPv4 addresses: `"${cluster.networking.ipv4.subnet_prefix}.${specs.start_ip + i}"` (locals.tf:26)
- IPv6 addresses (if enabled): `"${cluster.networking.ipv6.subnet_prefix}::${specs.start_ip + i}"` (locals.tf:35)
- VLAN IDs default to: `"${cluster.cluster_id}00"` if not explicitly set (locals.tf:24)

### Firewall Architecture

When `use_pve_firewall` is enabled (firewall.tf):
- Creates datacenter-level aliases for each node's IPs (IPv4/IPv6)
- Groups nodes into IPsets (all nodes, controlplane, etcd, workers, management IPs, load balancers)
- Defines security groups for K8s components (API, kubelet, etcd, cilium, metrics-server, nodeport, load balancers)
- Applies all security groups to each VM via `proxmox_virtual_environment_firewall_rules`
- Default policy is `input_policy = "DROP"` with explicit allow rules

### Cluster Configuration Export

Terraform writes the cluster configuration to JSON for Ansible consumption:
- Output path: `../ansible/tmp/${cluster_name}/cluster_config.json` (locals.tf:59)
- This bridges Terraform infrastructure with Ansible configuration management

## Common Commands

### Terraform Operations

```bash
# Initialize (download providers)
terraform init

# Select cluster workspace
terraform workspace select k3s    # or alpha, beta, gamma

# View current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Plan changes for current workspace
terraform plan

# Apply changes for current workspace
terraform apply

# Destroy resources in current workspace
terraform destroy

# View state for specific resource
terraform state show 'proxmox_virtual_environment_vm.node["k3s-controlplane-0"]'
```

### Workspace-Specific Operations

Each workspace maintains independent state files in `terraform.tfstate.d/<workspace>/`.

```bash
# Create and provision a new cluster
terraform workspace new delta
# (Add "delta" configuration to clusters.tf variable)
terraform apply

# Switch between clusters
terraform workspace select alpha
terraform plan  # Shows changes only for alpha cluster
```

## Secrets Management

Sensitive values are stored in `secrets.tf` (gitignored):
- `var.proxmox_api_token`: Proxmox API authentication
- `var.proxmox_username`: SSH username for Proxmox
- `var.unifi_username` / `var.unifi_password`: UniFi controller credentials
- `var.vm_ssh_key`: Public SSH keys for VM access
- `var.vm_password` / `var.vm_username`: VM user credentials

## Integration with Ansible

After Terraform provisions VMs, Ansible handles Kubernetes cluster setup:
- See `ansible/QUICK_START.md` for installation steps
- Ansible inventory should be generated/updated based on Terraform outputs
- K3s cluster setup playbook: `ansible-playbook playbooks/k3s-cluster-setup.yml`
- Kubeconfig files are created per cluster (e.g., `~/.kube/k3s.yml`)

## Provider Configuration

- **Proxmox**: Uses `bpg/proxmox` provider with SSH agent authentication
- **UniFi**: Uses `paultyng/unifi` provider for VLAN creation (optional per cluster)
- Template VM ID: `9000` (defined in locals.tf:4)
- Default Proxmox node: `proxmox01` (locals.tf:3)

## Important Lifecycle Rules

The VM resource has extensive `ignore_changes` to prevent accidental data loss (nodes.tf:126-140):
- `disk` is protected to prevent recreation and data loss
- `initialization` is ignored to prevent VM recreation on cloud-init changes
- `hostpci` is ignored due to Proxmox resource mapping behavior
