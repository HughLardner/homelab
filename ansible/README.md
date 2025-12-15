# Homelab Ansible - K3s Deployment

Ansible automation for deploying a K3s cluster on Proxmox VMs. Currently configured for single-node deployment (scalable to 3-node HA).

## Configuration Architecture

All configuration is centralized in `config/homelab.yaml` - the **single source of truth**.

```
config/
├── homelab.yaml    # All non-secret configuration (domains, replicas, etc.)
└── secrets.yml     # Secrets (gitignored, used by Ansible)
```

### How Ansible Uses Configuration

```yaml
# Playbooks load configuration via vars_files
- name: Deploy Service
  hosts: k3s_masters[0]
  vars_files:
    - "{{ playbook_dir }}/../../config/homelab.yaml"
    - "{{ playbook_dir }}/../../config/secrets.yml"
  tasks:
    - name: Deploy via Helm
      kubernetes.core.helm:
        name: service-name
        chart_ref: "{{ playbook_dir }}/../../kubernetes/services/service-name"
        values_files:
          - "{{ playbook_dir }}/../../config/homelab.yaml"
```

All service configuration (domains, replicas, cert issuers, etc.) comes from `config/homelab.yaml`.

## Quick Start

### 1. Configure Your Homelab

```bash
# Set up configuration
cp config/homelab.yaml.example config/homelab.yaml
vim config/homelab.yaml  # Edit your configuration

# Set up secrets
cp secrets.example.yml config/secrets.yml
vim config/secrets.yml  # Add your secrets
```

### 2. Generate Inventory from Terraform

The inventory only contains node IPs (dynamic data from Terraform). All service configuration comes from `config/homelab.yaml`.

```bash
# From project root
make inventory

# Or manually
cd ansible/inventory
python3 generate_inventory.py --format yaml > hosts.yml
```

### 3. Install K3s Cluster

```bash
# Using Makefile (recommended)
make k3s-install

# Or directly with Ansible
cd ansible
ansible-playbook playbooks/k3s-cluster-setup.yml
```

### 4. Access Your Cluster

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

# Core Services (deployed as Helm charts)
make metallb-install         # Install MetalLB LoadBalancer
make longhorn-install        # Install Longhorn storage
make cert-manager-install    # Install cert-manager for TLS
make traefik-install         # Install Traefik ingress controller
make argocd-install          # Install ArgoCD GitOps platform
make sealed-secrets-install  # Install Sealed Secrets controller
make seal-secrets            # Encrypt secrets from config/secrets.yml

# Full Stack Deployment
make deploy-all        # Deploy everything (infra + platform + services + apps)
make deploy-services   # Deploy infrastructure + K3s + all core services
make deploy-platform   # Deploy infrastructure + K3s cluster
make deploy-infra      # Deploy infrastructure only (Terraform VMs)
make deploy            # Alias for deploy-services

# Utilities
make ping              # Test connectivity to all nodes
make ssh-node          # SSH to the cluster node
```

## Project Structure

```
ansible/
├── ansible.cfg                      # Ansible configuration
├── inventory/
│   ├── generate_inventory.py       # Generates hosts.yml from Terraform output
│   └── hosts.yml                   # Generated inventory (node IPs only)
├── playbooks/
│   ├── k3s-cluster-setup.yml       # Main K3s installation playbook
│   ├── node-prep.yml               # Node preparation tasks
│   ├── metallb.yml                 # MetalLB LoadBalancer setup
│   ├── longhorn.yml                # Longhorn storage (via Helm)
│   ├── cert-manager.yml            # Cert-manager for TLS
│   ├── traefik.yml                 # Traefik ingress (via Helm)
│   ├── argocd.yml                  # ArgoCD GitOps (via Helm)
│   ├── authelia.yml                # Authelia SSO (via Helm)
│   ├── sealed-secrets.yml          # Sealed Secrets controller
│   ├── seal-secrets.yml            # Encrypt secrets for GitOps
│   ├── monitoring.yml              # Victoria Metrics + Grafana (via Helm)
│   └── monitoring-secrets.yml      # Create monitoring secrets
└── roles/
    ├── k3s/
    │   ├── defaults/main.yml       # Default variables
    │   ├── vars/main.yml           # Internal variables
    │   ├── handlers/main.yml       # Service handlers
    │   └── tasks/
    │       ├── main.yml            # Core installation logic
    │       └── kubeconfig.yml      # Kubeconfig management
    └── node-prep/
        ├── defaults/main.yml       # Node prep defaults
        └── tasks/main.yml          # System preparation tasks
```

## How the Configuration Flow Works

```
┌────────────────────────────────────────────────────────────────┐
│ config/homelab.yaml (Single Source of Truth)                   │
│  - domains, replicas, cert issuers, etc.                       │
└────────────────────────────────────────────────────────────────┘
           ↓
┌────────────────────────────────────────────────────────────────┐
│ Ansible Playbook (vars_files loads config)                     │
│  - kubernetes.core.helm deploys Helm charts                    │
│  - Charts read values from config/homelab.yaml                 │
└────────────────────────────────────────────────────────────────┘
           ↓
┌────────────────────────────────────────────────────────────────┐
│ Helm Charts (kubernetes/services/*)                            │
│  - Templates use {{ .Values.services.* }} from config          │
│  - Certificates, IngressRoutes, etc. use consistent values     │
└────────────────────────────────────────────────────────────────┘
```

### Inventory vs Configuration

**`ansible/inventory/hosts.yml`** - Only contains:
- Node IPs (dynamic, from Terraform)
- SSH connection settings

**`config/homelab.yaml`** - Contains all service configuration:
- Domains (traefik, argocd, grafana, etc.)
- Cert issuers, replicas, resource limits
- Global settings

This separation means:
- Terraform generates node IPs → `hosts.yml`
- Static configuration → `config/homelab.yaml`
- Secrets → `config/secrets.yml`

## Configuration

### Editing Configuration

All service configuration is in `config/homelab.yaml`:

```yaml
global:
  domain: silverseekers.org
  cert_issuer: letsencrypt-prod
  email: your@email.com

services:
  traefik:
    domain: traefik.silverseekers.org
    replicas: 2
  argocd:
    domain: argocd.silverseekers.org
  authelia:
    domain: auth.silverseekers.org
  grafana:
    domain: grafana.silverseekers.org
```

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

The `generate_inventory.py` script reads Terraform's output and generates a minimal inventory:

- Reads: `ansible/tmp/<cluster>/cluster_config.json`
- Outputs: `ansible/inventory/hosts.yml`
- Contains: Node IPs and SSH connection settings only

All service configuration comes from `config/homelab.yaml` via `vars_files`.

### 2. K3s Installation

The playbook installs K3s in sequence:

1. **First Master**: Install with `--cluster-init` (creates HA embedded etcd)
2. **Wait**: Ensure API is ready
3. **Additional Masters**: Join using token from first master
4. **Verify**: Check all nodes are Ready
5. **Kubeconfig**: Copy and configure local kubeconfig

### 3. Service Deployment

Services are deployed as Helm charts:

```yaml
- name: Deploy Authelia Ingress
  kubernetes.core.helm:
    name: authelia-ingress
    chart_ref: "{{ playbook_dir }}/../../kubernetes/services/authelia"
    release_namespace: authelia
    create_namespace: true
    values_files:
      - "{{ playbook_dir }}/../../config/homelab.yaml"
```

## Troubleshooting

### Connectivity Issues

```bash
# Test ping
make ping

# Check SSH access
make ssh-node
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
2. **Inventory Generator** reads the config and creates minimal inventory (node IPs only)
3. **Ansible** loads `config/homelab.yaml` and deploys services

This creates a clean separation:
- Terraform = Infrastructure layer (VMs, node IPs)
- config/homelab.yaml = Service configuration
- Ansible = Deployment orchestration

## Secrets Management

This project uses **Sealed Secrets** to encrypt Kubernetes secrets for safe storage in Git:

```bash
# 1. Create your secrets file from the template
cp secrets.example.yml config/secrets.yml
vim config/secrets.yml

# 2. Encrypt secrets and commit to git
make seal-secrets

# 3. The playbook will:
#    - Validate secrets.yml format
#    - Encrypt each secret with kubeseal
#    - Save sealed secrets to kubernetes/ directories
#    - Git add and commit the sealed secrets
```

See [SECRETS.md](../SECRETS.md) for comprehensive secrets management documentation.

## Next Steps

After K3s and core services are installed, you can:

1. **Deploy Applications**: Use ArgoCD or kubectl to deploy workloads
2. **Configure Secrets**: Use Sealed Secrets for GitOps-safe secret management
3. **Add Monitoring**: Deploy Prometheus/Grafana stack (`make monitoring-install`)
4. **Set up GitOps**: Configure ArgoCD applications for continuous delivery

## Documentation

- [Main README](../README.md) - Complete homelab guide
- [SECRETS.md](../SECRETS.md) - Secrets management with Sealed Secrets
- [Kubernetes README](../kubernetes/README.md) - Services and applications
- [Terraform README](../terraform/README.md) - Infrastructure provisioning

See the main project documentation for detailed deployment guides.
