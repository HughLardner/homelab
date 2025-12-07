# Simplified Homelab Terraform Configuration

This Terraform configuration creates a 3-node Kubernetes cluster on a single Proxmox host.

## Hardware Setup
- **Host**: Beelink Mini PC (Intel N150, 16GB RAM, 500GB SSD)
- **Network**: VLAN 10, 192.168.10.0/24
- **Proxmox**: 192.168.10.10

## Cluster Configuration

The cluster creates 3 identical VMs that serve as combined control plane + worker nodes:

| Node | VM ID | IP Address | Cores | Memory | Disk |
|------|-------|------------|-------|--------|------|
| homelab-node-0 | 120 | 192.168.10.20 | 4 | 4GB | 50GB |
| homelab-node-1 | 121 | 192.168.10.21 | 4 | 4GB | 50GB |
| homelab-node-2 | 122 | 192.168.10.22 | 4 | 4GB | 50GB |

**Total Resource Usage**: 12 cores (all 4 cores × 3), 12GB RAM (leaving 4GB for Proxmox)

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

- **clusters.tf**: Main cluster configuration (edit this to change VM specs)
- **locals.tf**: Proxmox host settings and node generation logic
- **nodes.tf**: VM resource definitions
- **pool.tf**: Creates Proxmox resource pool "HOMELAB"
- **providers.tf**: Proxmox provider configuration
- **secrets.tf**: SSH keys and credentials (should be gitignored)

## Customization

To change cluster settings, edit `clusters.tf`:

```hcl
variable "cluster" {
  default = {
    cluster_name   = "homelab"       # Cluster name
    node_count     = 3               # Number of nodes
    node_start_ip  = 20              # First node IP: .20, .21, .22
    cores          = 4               # CPU cores per node
    memory         = 4096            # RAM per node (MB)
    disk_size      = 50              # Disk size per node (GB)
    kube_vip       = "192.168.10.15" # K8s API VIP
    lb_cidrs       = "192.168.10.150/28" # MetalLB range
    # ... other settings
  }
}
```

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

After Terraform creates the VMs:
1. Use Ansible to install Kubernetes (see `../ansible/QUICK_START.md`)
2. Configure kubectl with the generated kubeconfig
3. Deploy cluster services (MetalLB, Ingress, cert-manager, etc.)
