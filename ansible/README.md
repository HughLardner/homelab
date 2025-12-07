# Homelab Ansible - K3s Deployment

Simplified Ansible automation for deploying K3s clusters on Proxmox VMs.

## Quick Start

### 1. Generate Inventory from Terraform

The inventory is automatically generated from Terraform's cluster configuration:

```bash
# From project root
make inventory

# Or manually
cd ansible/inventory
python3 generate_inventory.py --format yaml > hosts.yml
```

### 2. Install K3s Cluster

```bash
# Using Makefile (recommended)
make k3s-install

# Or directly with Ansible
cd ansible
ansible-playbook playbooks/k3s-cluster-setup.yml
```

### 3. Access Your Cluster

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/config-homelab

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

## Makefile Commands

The Makefile provides convenient shortcuts for common operations:

```bash
make help              # Show all available commands
make inventory         # Generate Ansible inventory from Terraform
make k3s-install       # Install K3s cluster
make k3s-status        # Check K3s service status
make k3s-destroy       # Uninstall K3s from all nodes
make metallb-install   # Install MetalLB LoadBalancer
make metallb-test      # Install MetalLB with test LoadBalancer
make ping              # Test connectivity to all nodes
make ssh-node1         # SSH to first node
make deploy            # Full stack: terraform apply + inventory + k3s install
```

## Project Structure

```
ansible/
├── ansible.cfg                    # Simplified Ansible configuration
├── inventory/
│   ├── generate_inventory.py     # Auto-generate from Terraform
│   └── hosts.yml                  # Generated inventory (not committed)
├── playbooks/
│   ├── k3s-cluster-setup.yml     # Main K3s installation playbook
│   ├── metallb.yml                # MetalLB LoadBalancer setup
│   └── node-prep.yml              # Node preparation tasks
└── roles/
    ├── k3s/
    │   ├── defaults/main.yml      # Default variables
    │   ├── vars/main.yml          # Internal variables
    │   ├── handlers/main.yml      # Service handlers
    │   └── tasks/
    │       ├── main.yml           # Core installation logic
    │       └── kubeconfig.yml     # Kubeconfig management
    └── node-prep/
        ├── defaults/main.yml      # Node prep defaults
        └── tasks/main.yml         # System preparation tasks

Total: ~450 lines of Ansible code
```

## Configuration

### K3s Version

Override the K3s version:

```bash
ansible-playbook playbooks/k3s-cluster-setup.yml -e k3s_version=v1.34.0+k3s1
```

### Role Variables

Key variables in `roles/k3s/defaults/main.yml`:

```yaml
k3s_version: "v1.33.5+k3s1"
k3s_disable_traefik: true
k3s_disable_servicelb: true
k3s_write_kubeconfig_mode: 644
k3s_local_kubeconfig_name: "config-homelab"
```

## How It Works

### 1. Inventory Generation

The `generate_inventory.py` script reads Terraform's `cluster_config.json` and generates a dynamic inventory:

- Reads: `ansible/tmp/<cluster>/cluster_config.json`
- Outputs: `ansible/inventory/hosts.yml`
- Includes: Node IPs, cluster vars, SSH settings

This ensures your inventory is always in sync with Terraform state.

### 2. K3s Installation

The playbook installs K3s in sequence:

1. **First Master**: Install with `--cluster-init` (creates HA embedded etcd)
2. **Wait**: Ensure API is ready
3. **Additional Masters**: Join using token from first master
4. **Verify**: Check all nodes are Ready
5. **Kubeconfig**: Copy and configure local kubeconfig

### 3. Serial Execution

The playbook uses `serial: 1` to install nodes one at a time, ensuring:
- First master is fully ready before additional masters join
- Stable HA setup with embedded etcd
- Better error handling and visibility

## Simplifications from Original

This simplified version removes:

- ❌ Excessive DNS validation (Terraform already validates)
- ❌ Disk space pre-checks (fails naturally if insufficient)
- ❌ Multiple validation layers (rely on K3s installer)
- ❌ Complex error handling (fail fast, clear errors)
- ❌ Manual inventory management (auto-generated)

**Result**: 62% less code, faster execution, easier maintenance.

## Troubleshooting

### Connectivity Issues

```bash
# Test ping
make ping

# Check SSH access
make ssh-node1
```

### Installation Fails

```bash
# Check k3s service status
make k3s-status

# View logs on specific node
ssh ubuntu@192.168.10.20 'sudo journalctl -u k3s -n 50'
```

### Regenerate Inventory

If Terraform state changes:

```bash
make inventory
```

### Clean Install

```bash
# Uninstall K3s
make k3s-destroy

# Reinstall
make k3s-install
```

## Integration with Terraform

The Ansible setup integrates seamlessly with Terraform:

1. **Terraform** provisions VMs and writes `cluster_config.json`
2. **Inventory Generator** reads the config and creates inventory
3. **Ansible** deploys K3s using the generated inventory

This creates a clean separation:
- Terraform = Infrastructure layer
- Ansible = Application layer

## MetalLB Installation

After K3s is installed, deploy MetalLB for LoadBalancer services:

### Install MetalLB

```bash
# Install MetalLB
make metallb-install

# Or with test LoadBalancer deployment
make metallb-test
```

### Configuration

MetalLB IP pool is configured in the inventory (`metallb_ipv4_pools` variable):

```yaml
all:
  children:
    k3s_cluster:
      vars:
        metallb_ipv4_pools: 192.168.10.150/28  # From Terraform cluster config
```

### Verify Installation

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# View IP address pool
kubectl get ipaddresspool -n metallb-system

# View L2 advertisement
kubectl get l2advertisement -n metallb-system
```

### Test LoadBalancer

If you used `make metallb-test`, a test nginx service is deployed:

```bash
# Get the LoadBalancer IP
kubectl get svc nginx-test

# Test the service
curl http://<EXTERNAL-IP>

# Clean up test service
kubectl delete deployment nginx-test
kubectl delete service nginx-test
```

## Next Steps

After K3s and MetalLB are installed, you can:

1. Deploy applications with LoadBalancer services
2. Install ArgoCD for GitOps
3. Deploy Ingress Controller (nginx-ingress)
4. Deploy monitoring stack (Prometheus/Grafana)

See the main project documentation for application deployment guides.
