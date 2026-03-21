# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This homelab infrastructure deploys a **single-node Kubernetes (K3s) cluster** on Proxmox VE, optimized for low-power hardware (12GB RAM). The infrastructure supports scaling to multi-node HA clusters via configuration changes.

### Current Deployment
- **Single node**: 192.168.10.20 (12GB RAM, 100GB disk)
- **Domain**: *.silverseekers.org → 192.168.10.150 (Traefik LoadBalancer)
- **Proxmox**: Upgraded to Proxmox VE 9 (March 2026)

**Bootstrap Services** (Ansible — must exist before ArgoCD):
MetalLB, Longhorn, Sealed Secrets, ArgoCD

**Platform Services** (ArgoCD Wave 1–4):
Cert-Manager, Traefik, Authelia, Network Policies, Resource Policies, Loki, Promtail, Garage (S3), Velero, Cloudflared, External-DNS, Intel Device Plugins

**Applications** (ArgoCD Wave 5+):
Monitoring (Victoria Metrics + Grafana), Homepage, Home Assistant, Node-RED, Zigbee2MQTT, Mosquitto, Pi-hole, Plex, Filebrowser, Forgejo, Quartz, Obsidian LiveSync, Headlamp

## Unified Configuration Architecture

### Single Source of Truth

All configuration is centralized in `config/homelab.yaml`:

```
config/
├── homelab.yaml    # All non-secret configuration (domains, replicas, etc.)
└── secrets.yml     # Secrets (gitignored, never committed)
```

This file is used by **all tools**:

| Tool | How It Reads Config |
|------|---------------------|
| **Terraform** | `yamldecode(file("../config/homelab.yaml"))` |
| **Ansible** | `vars_files: ["../../config/homelab.yaml"]` |
| **Helm/ArgoCD** | `valueFiles: ["config/homelab.yaml"]` |

### Configuration Structure

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
  lb_cidrs: "192.168.10.150/28"
  ssh_user: ubuntu

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
  longhorn:
    domain: longhorn.silverseekers.org
    data_path: /mnt/longhorn-data    # 200GB standalone Proxmox LV
  garage:
    domain: s3.silverseekers.org     # S3-compatible storage (replaces MinIO)
  velero:
    backup_schedule: "0 2 * * *"
  external_dns:
    domain: silverseekers.org
    provider: cloudflare
  cloudflared:
    tunnel_name: homelab-tunnel      # Only fallandrise.silverseekers.org exposed publicly
  # ... and more — see config/homelab.yaml for the full list of 25+ services
```

### Benefits

- **One file to edit** for any configuration change
- **No duplication** between Terraform, Ansible, and Kubernetes
- **ArgoCD compatibility** - Helm charts work natively with GitOps
- **Consistent values** across all deployment methods

## Service Architecture

### Helm Charts (Co-located)

Each service is packaged as a Helm chart, co-located with its service directory:

```
kubernetes/services/authelia/
├── Chart.yaml              # Helm chart metadata
├── values.yaml             # Default values
├── authelia-values.yaml    # Upstream Helm chart values
├── templates/
│   ├── certificate.yaml    # TLS certificate
│   ├── ingressroute.yaml   # Traefik IngressRoute
│   └── middleware.yaml     # Traefik middleware
├── secrets/
│   └── authelia-secrets-sealed.yaml
└── README.md
```

### Deployment Methods

All use the same `config/homelab.yaml`:

**1. Helm directly:**
```bash
helm upgrade --install authelia-ingress ./kubernetes/services/authelia \
  -f ./config/homelab.yaml -n authelia --create-namespace
```

**2. Ansible (via kubernetes.core.helm):**
```yaml
- name: Deploy via Helm
  kubernetes.core.helm:
    name: authelia-ingress
    chart_ref: "{{ playbook_dir }}/../../kubernetes/services/authelia"
    values_files:
      - "{{ playbook_dir }}/../../config/homelab.yaml"
```

**3. ArgoCD (via multi-source Applications):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  sources:
    - repoURL: https://github.com/HughLardner/homelab.git
      path: kubernetes/services/authelia
      helm:
        valueFiles:
          - $values/config/homelab.yaml
    - repoURL: https://github.com/HughLardner/homelab.git
      ref: values
```

## Key Architecture Concepts

### VM ID and IP Generation

From `config/homelab.yaml` infrastructure section:
- Node IPs: `${subnet_prefix}.${node_start_ip + i}` → 192.168.10.20
- VM IDs: `${cluster.id}${node_start_ip + i}` → 120

### Inventory Generation

`ansible/inventory/generate_inventory.py` outputs **only node IPs**:

```yaml
all:
  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
            homelab-node-0:
              ansible_host: 192.168.10.20
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519_personal
```

All service configuration comes from `config/homelab.yaml` via `vars_files`.

### Cluster Configuration Export

Terraform writes dynamic data to JSON for Ansible:
- Output path: `ansible/tmp/${cluster_name}/cluster_config.json`
- Contains: node IPs (dynamic data from Terraform)
- **Static configuration** comes from `config/homelab.yaml`

## Common Commands

### Full Stack Deployment
```bash
make deploy-all        # Everything: Terraform → K3s → Services → Apps
make deploy-services   # Infrastructure + platform + services
make deploy-platform   # Infrastructure + K3s only
```

### Individual Service Deployment
```bash
# Via Helm
helm upgrade --install traefik-ingress ./kubernetes/services/traefik \
  -f ./config/homelab.yaml -n traefik --create-namespace

# Via Ansible
make traefik-install

# Via ArgoCD (automatic on git push)
git push
```

### Terraform Operations

```bash
# Initialize (download providers)
terraform init

# Select cluster workspace
terraform workspace select k3s    # or alpha, beta, gamma

# Plan changes for current workspace
terraform plan

# Apply changes for current workspace
terraform apply

# Destroy resources in current workspace
terraform destroy
```

### Ansible Operations
```bash
# Generate inventory from Terraform
make inventory

# Install K3s
make k3s-install

# Bootstrap services (Ansible — must run before ArgoCD)
make metallb-install
make longhorn-install
make sealed-secrets-install
make argocd-install

# Platform services (Ansible or ArgoCD via root-app)
make cert-manager-install
make traefik-install
make authelia-install

# After ArgoCD is running — deploy everything else via GitOps
kubectl apply -f kubernetes/applications/root-app.yaml

# Secrets management
make seal-secrets      # Encrypt config/secrets.yml → sealed yaml files
```

## Secrets Management

### Plain Secrets
- Location: `config/secrets.yml` (gitignored)
- Used by: Ansible playbooks via `vars_files`
- Template: `secrets.example.yml`

### Sealed Secrets
- Encrypted secrets safe for Git
- Location: `kubernetes/*/secrets/*-sealed.yaml`
- Decrypted by sealed-secrets controller in cluster
- Services with sealed secrets: argocd, authelia, cert-manager, cloudflared, external-dns, garage, velero, monitoring (Grafana admin), home-assistant (OIDC), node-red (OIDC)

### Terraform Secrets
- Location: `terraform/secrets.tf` (gitignored)
- Contains: Proxmox API credentials, SSH keys

### Backup of Sealed Secrets Key
- **Critical**: Export and back up the sealed-secrets encryption key before any cluster rebuild
- See `docs/PRE_PROXMOX9_BACKUP.md` for the backup checklist pattern

## Directory Structure

```
homelab/
├── config/
│   ├── homelab.yaml          # Single source of truth for all configuration
│   ├── homelab.yaml.example  # Template for new users
│   └── secrets.yml           # Plain secrets (gitignored)
├── terraform/
│   ├── clusters.tf           # Reads config/homelab.yaml
│   ├── locals.tf
│   ├── nodes.tf
│   ├── secrets.tf            # Proxmox API credentials (gitignored)
│   ├── ha.tf.disabled        # HA Terraform config (disabled)
│   └── unifi.tf.disabled     # UniFi VLAN creation (disabled)
├── ansible/
│   ├── inventory/
│   │   ├── hosts.yml         # Node IPs only (generated, empty placeholder)
│   │   └── generate_inventory.py
│   └── playbooks/
│       └── *.yml             # Load config via vars_files (22 playbooks)
├── kubernetes/
│   ├── services/             # Platform services (Helm charts, co-located)
│   │   ├── argocd/           # GitOps platform
│   │   ├── authelia/         # SSO/2FA
│   │   ├── cert-manager/     # TLS automation
│   │   ├── cloudflared/      # Cloudflare tunnel
│   │   ├── coredns/          # CoreDNS custom config
│   │   ├── external-dns/     # DNS automation (Cloudflare)
│   │   ├── garage/           # S3-compatible object storage
│   │   ├── intel-device-plugins/ # Intel GPU passthrough
│   │   ├── loki/             # Log aggregation
│   │   ├── longhorn/         # Distributed block storage
│   │   ├── metallb/          # LoadBalancer (Kustomize)
│   │   ├── network-policies/ # Namespace isolation
│   │   ├── promtail/         # Log collection
│   │   ├── resource-policies/# LimitRange/ResourceQuota
│   │   ├── sealed-secrets/   # Secret encryption controller
│   │   ├── traefik/          # Ingress controller
│   │   └── velero/           # Backup/restore
│   └── applications/         # Workloads (Helm charts, co-located)
│       ├── root-app.yaml     # App-of-apps (manages all application.yaml files)
│       ├── monitoring/       # Victoria Metrics + Grafana
│       ├── home-assistant/   # Home automation
│       ├── homepage/         # Dashboard
│       ├── headlamp/         # Kubernetes UI
│       ├── forgejo/          # Self-hosted Git
│       ├── plex/             # Media server (on-demand via HA toggle)
│       ├── mosquitto/        # MQTT broker
│       ├── node-red/         # IoT automation (OIDC)
│       ├── zigbee2mqtt/      # Zigbee coordinator (SMLIGHT SLZB TCP)
│       ├── pihole/           # DNS ad-blocker (192.168.10.152)
│       ├── quartz/           # Digital garden (fallandrise.silverseekers.org)
│       ├── obsidian-livesync/# CouchDB for Obsidian sync
│       └── root-app.yaml     # App-of-apps pattern
├── docs/
│   ├── ADDING_APPLICATIONS.md
│   ├── GRAFANA_MCP.md
│   ├── PERSISTENT_STORAGE.md
│   ├── CURSOR_REMOTE_SSH.md
│   ├── PRE_PROXMOX9_BACKUP.md
│   ├── CLUSTER_STATE_SNAPSHOT_*.md
│   └── runbooks/
│       └── node-io-saturation-recovery.md
├── Makefile
├── README.md
├── SECRETS.md
├── HA_CONFIGURATION.md
└── CLAUDE.md
```

## Provider Configuration

- **Proxmox**: Uses `bpg/proxmox` provider with SSH agent authentication
- **UniFi**: Uses `paultyng/unifi` provider for VLAN creation (optional per cluster)
- Template VM ID: `9000` (defined in locals.tf)
- Default Proxmox node: `proxmox01`

## Important Lifecycle Rules

The VM resource has extensive `ignore_changes` to prevent accidental data loss (nodes.tf):
- `disk` is protected to prevent recreation and data loss
- `initialization` is ignored to prevent VM recreation on cloud-init changes
- `hostpci` is ignored due to Proxmox resource mapping behavior
