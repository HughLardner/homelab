# K3s Cluster - Quick Start Guide

Get your K3s cluster running in 3 commands!

## Prerequisites

- ✅ VMs provisioned via Terraform
- ✅ SSH access configured
- ✅ Ansible installed locally

## Installation (3 Steps)

### Step 1: Generate Inventory

```bash
cd /Users/hlardner/projects/personal/homelab
make inventory
```

This reads Terraform's cluster configuration and generates the Ansible inventory automatically.

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

Expected output:
```
NAME              STATUS   ROLES                       AGE   VERSION
homelab-node-0    Ready    control-plane,etcd,master   2m    v1.33.5+k3s1
homelab-node-1    Ready    control-plane,etcd,master   1m    v1.33.5+k3s1
homelab-node-2    Ready    control-plane,etcd,master   1m    v1.33.5+k3s1
```

## Quick Commands

```bash
# Test connectivity
make ping

# Check K3s status
make k3s-status

# SSH to nodes
make ssh-node1
make ssh-node2
make ssh-node3

# View cluster info
kubectl get nodes -o wide
kubectl get pods -A

# Uninstall K3s (careful!)
make k3s-destroy
```

## Full Stack Deployment

Deploy everything from scratch:

```bash
# 1. Provision infrastructure
cd terraform
terraform workspace select homelab
terraform apply

# 2. Deploy K3s
cd ..
make inventory
make k3s-install

# 3. Verify
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
```

Or use the combined command:

```bash
make deploy  # Does terraform apply + inventory + k3s install
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
- DNS is working: `make ssh-node1` then `nslookup get.k3s.io`

## Next Steps

After successful installation:

1. **Networking**: Install MetalLB for LoadBalancer services
   ```bash
   make metallb-install
   ```

2. **Storage**: Deploy Longhorn for persistent storage

3. **GitOps**: Deploy ArgoCD for application management

4. **Monitoring**: Install kube-prometheus-stack

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
cd .. && make deploy
```

## Help

```bash
make help  # Show all available commands
```

For issues, check:
- Ansible logs: `ansible/logs/ansible.log` (if enabled)
- K3s logs: `journalctl -u k3s -f` (on nodes)
- Cluster events: `kubectl get events -A`
