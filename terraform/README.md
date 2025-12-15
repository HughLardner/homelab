# Homelab Terraform Configuration

This Terraform configuration creates a single-node Kubernetes cluster on a Proxmox host, optimized for low-power hardware.

## Configuration Architecture

All configuration is centralized in `config/homelab.yaml` - the **single source of truth**.

Terraform reads this configuration file directly:

```hcl
# clusters.tf
locals {
  config = yamldecode(file("${path.module}/../config/homelab.yaml"))
}

# Use values: local.config.cluster.name, local.config.infrastructure.node_count, etc.
```

### Configuration File

```yaml
# config/homelab.yaml
cluster:
  name: homelab
  id: 1

infrastructure:
  node_count: 1
  node_start_ip: 20
  cores: 4
  memory: 12288
  disk_size: 100
  subnet_prefix: "192.168.10"
  gateway: "192.168.10.1"
  dns_servers: ["1.1.1.1", "1.0.0.1"]
  kube_vip: "192.168.10.15"
  kube_vip_hostname: homelab-api
  lb_cidrs: "192.168.10.150/28"
  ssh_user: ubuntu

global:
  domain: silverseekers.org
  cert_issuer: letsencrypt-prod
  email: your@email.com
```

## Hardware Setup
- **Host**: Beelink Mini PC (Intel N150, 16GB RAM, 500GB SSD)
- **Network**: VLAN 10, 192.168.10.0/24
- **Proxmox**: 192.168.10.10

## Cluster Configuration

The cluster creates a single VM that serves as combined control plane + worker node:

| Node | VM ID | IP Address | Cores | Memory | Disk |
|------|-------|------------|-------|--------|------|
| homelab-node-0 | 120 | 192.168.10.20 | 4 | 12GB | 100GB |

**Total Resource Usage**: 4 cores, 12GB RAM (leaving ~3GB for Proxmox)

### Scaling to Multi-Node (Optional)

To scale to a 3-node HA cluster, update `config/homelab.yaml`:

```yaml
infrastructure:
  node_count: 3
  memory: 4096  # 4GB per node (12GB total)
```

### Additional Network Configuration
- **Kube-VIP (K8s API)**: 192.168.10.15 (homelab-api)
- **MetalLB LoadBalancer Range**: 192.168.10.150-165 (16 IPs)
- **Gateway**: 192.168.10.1
- **DNS**: 1.1.1.1, 1.0.0.1

## Usage

### Initialize Terraform
```bash
terraform init
```

### Review planned changes
```bash
terraform plan
```

### Create the VMs
```bash
terraform apply
```

### Destroy the cluster
```bash
terraform destroy
```

## Configuration Files

- **clusters.tf**: Main cluster configuration (reads from `config/homelab.yaml`)
- **locals.tf**: Proxmox host settings and node generation logic
- **nodes.tf**: VM resource definitions
- **pool.tf**: Creates Proxmox resource pool "HOMELAB"
- **providers.tf**: Proxmox provider configuration
- **secrets.tf**: SSH keys and credentials (should be gitignored)

## Customization

To change cluster settings, edit `config/homelab.yaml`:

```yaml
cluster:
  name: homelab           # Cluster name
  id: 1                   # Cluster ID (for VM ID prefix)

infrastructure:
  node_count: 1           # Number of nodes (1 = single-node, 3 = HA)
  node_start_ip: 20       # First node IP: .20
  cores: 4                # CPU cores per node
  memory: 12288           # RAM per node (MB) - 12GB for single node
  disk_size: 100          # Disk size per node (GB)
  kube_vip: "192.168.10.15"       # K8s API VIP
  lb_cidrs: "192.168.10.150/28"   # MetalLB range (16 IPs)
```

### Key Configuration Options

| Setting | Current | For HA Cluster |
|---------|---------|----------------|
| `node_count` | 1 | 3 |
| `memory` | 12288 (12GB) | 4096 (4GB each) |
| `disk_size` | 100 | 50 |

## Integration with Other Tools

### Single Source of Truth

The same `config/homelab.yaml` file is used by:

| Tool | How It Reads Config |
|------|---------------------|
| **Terraform** | `yamldecode(file("../config/homelab.yaml"))` |
| **Ansible** | `vars_files: ["../../config/homelab.yaml"]` |
| **Helm/ArgoCD** | `valueFiles: ["config/homelab.yaml"]` |

### What Terraform Outputs

Terraform writes dynamic data (node IPs) to `ansible/tmp/<cluster>/cluster_config.json`:

```json
{
  "cluster_name": "homelab",
  "nodes": [
    {
      "name": "homelab-node-0",
      "ip": "192.168.10.20"
    }
  ]
}
```

This is used by `generate_inventory.py` to create the Ansible inventory with node IPs.

**Static configuration** (domains, cert issuers, etc.) comes from `config/homelab.yaml`.

## Disabled Features

The following features have been disabled for this simplified setup:
- High Availability (HA) - single Proxmox host
- Proxmox Firewall - managed at network level
- UniFi integration - not needed for basic VLAN setup

Files have been renamed with `.disabled` extension:
- `firewall.tf.disabled`
- `ha.tf.disabled`
- `unifi.tf.disabled`

## Next Steps

After Terraform creates the VMs, you have several options:

### Option 1: Full Stack Deployment (Recommended)
```bash
# From project root
make deploy-all
```
This deploys everything: VMs → K3s → Core Services → Applications

### Option 2: Manual Steps
```bash
# 1. Deploy infrastructure
cd terraform && terraform apply && cd ..

# 2. Install K3s cluster
make k3s-install

# 3. Deploy core services
make metallb-install
make longhorn-install
make cert-manager-install
make traefik-install
make argocd-install
make sealed-secrets-install

# 4. Deploy applications
make monitoring-install
```

### Option 3: Use Ansible Directly
See [../ansible/README.md](../ansible/README.md) for Ansible-specific commands.

### Full Documentation
- [Main README](../README.md) - Complete deployment guide
- [Ansible README](../ansible/README.md) - K3s cluster setup
- [Kubernetes README](../kubernetes/README.md) - Services and applications
- [SECRETS.md](../SECRETS.md) - Secrets management with Sealed Secrets
