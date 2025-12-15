# K3s Cluster - Quick Start Guide

Get your K3s cluster running in 3 commands! Currently configured for single-node deployment.

## Prerequisites

- ✅ VMs provisioned via Terraform
- ✅ SSH access configured
- ✅ Ansible installed locally
- ✅ Configuration set up (see below)

## Configuration Setup

All configuration is centralized in `config/homelab.yaml`:

```bash
# 1. Set up configuration (one-time)
cp config/homelab.yaml.example config/homelab.yaml
vim config/homelab.yaml  # Edit your values

# 2. Set up secrets (one-time)
cp secrets.example.yml config/secrets.yml
vim config/secrets.yml  # Add your secrets
```

## Installation (3 Steps)

### Step 1: Generate Inventory

```bash
cd /Users/hlardner/projects/personal/homelab
make inventory
```

This reads Terraform's cluster configuration and generates the Ansible inventory with node IPs.

### Step 2: Install K3s

```bash
make k3s-install
```

This will:
1. Install K3s on the first master
2. Wait for API to be ready
3. Install K3s on additional masters
4. Verify all nodes join the cluster
5. Configure local kubeconfig

**Time**: ~5-10 minutes for 3-node cluster

### Step 3: Verify Cluster

```bash
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
```

Expected output (single-node):
```
NAME              STATUS   ROLES                       AGE   VERSION
homelab-node-0    Ready    control-plane,etcd,master   2m    v1.33.5+k3s1
```

For a 3-node HA cluster, you would see all three nodes.

## Quick Commands

```bash
# Test connectivity
make ping

# Check K3s status
make k3s-status

# SSH to node
make ssh-node

# View cluster info
kubectl get nodes -o wide
kubectl get pods -A

# Uninstall K3s (careful!)
make k3s-destroy
```

## Full Stack Deployment

Deploy everything from scratch:

```bash
# 1. Set up configuration
cp config/homelab.yaml.example config/homelab.yaml
vim config/homelab.yaml

# 2. Provision infrastructure
cd terraform
terraform apply

# 3. Deploy K3s
cd ..
make inventory
make k3s-install

# 4. Verify
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
```

Or use the combined commands:

```bash
make deploy-all       # Deploy everything (infra + platform + services + apps)
make deploy-services  # Deploy infrastructure + K3s + all core services
make deploy-platform  # Deploy infrastructure + K3s cluster only
```

## Upgrading K3s

```bash
ansible-playbook ansible/playbooks/k3s-cluster-setup.yml \
  -e k3s_version=v1.34.0+k3s1
```

## Troubleshooting

### "Inventory not found"

```bash
# Regenerate from Terraform
make inventory
```

### "Cannot connect to nodes"

```bash
# Check Terraform created VMs
cd terraform && terraform output

# Test SSH
make ping
```

### "K3s installation fails"

```bash
# Check logs on node
ssh ubuntu@192.168.10.20 'sudo journalctl -u k3s -n 50'

# Retry installation
make k3s-install
```

### "DNS issues during install"

K3s needs to download from `get.k3s.io`. Ensure:
- VMs have internet access
- DNS is working: `make ssh-node` then `nslookup get.k3s.io`

## Next Steps

After successful installation:

1. **Core Services**: Deploy all platform services
   ```bash
   make metallb-install
   make longhorn-install
   make cert-manager-install
   make traefik-install
   make argocd-install
   make sealed-secrets-install
   ```

2. **Authentication**: Deploy Authelia for SSO
   ```bash
   make authelia-install
   ```

3. **Monitoring**: Install Victoria Metrics + Grafana
   ```bash
   make monitoring-secrets
   make monitoring-install
   ```

See the main project docs for detailed guides.

## Clean Slate

To completely reset:

```bash
# 1. Uninstall K3s
make k3s-destroy

# 2. Destroy VMs
cd terraform && terraform destroy

# 3. Recreate everything
terraform apply
cd .. && make deploy-all
```

## Help

```bash
make help  # Show all available commands
```

For issues, check:
- Ansible logs: `ansible/logs/ansible.log` (if enabled)
- K3s logs: `journalctl -u k3s -f` (on nodes)
- Cluster events: `kubectl get events -A`

## Documentation

- [Main README](../README.md) - Complete deployment guide
- [Ansible README](README.md) - Detailed Ansible usage
- [SECRETS.md](../SECRETS.md) - Secrets management
- [Kubernetes README](../kubernetes/README.md) - Services and applications
