# Kubernetes Manifests

This directory contains Kubernetes manifest files for deploying and managing services and applications on your K3s clusters.

## Directory Structure

```
kubernetes/
├── README.md              # This file
├── applications/          # Applications managed by ArgoCD
│   ├── README.md          # Applications documentation
│   ├── root-app.yaml      # App-of-Apps pattern
│   └── monitoring/        # Prometheus + Grafana stack
│       ├── application.yaml
│       ├── values.yaml
│       ├── ingressroute.yaml
│       └── README.md
└── services/              # Infrastructure services
    ├── metallb/           # MetalLB LoadBalancer
    ├── longhorn/          # Distributed block storage
    ├── cert-manager/      # TLS certificate automation
    ├── traefik/           # Ingress controller
    ├── argocd/            # GitOps platform
    └── sealed-secrets/    # Secret encryption for GitOps
```

## Purpose and Philosophy

### Infrastructure Layer Separation

This directory represents the **application and service layer** of your infrastructure:

| Layer | Tool | Purpose | Location |
|-------|------|---------|----------|
| **Infrastructure** | Terraform | VMs, networks, storage | `terraform/` |
| **Platform** | Ansible | K3s, OS config | `ansible/` |
| **Services** | kubectl/GitOps | Networking, storage, ingress | `kubernetes/services/` |
| **Applications** | kubectl/GitOps | Your workloads | `kubernetes/apps/` |

### Deployment Methods

**Option 1: Manual (kubectl)**
```bash
# Apply specific service
kubectl apply -k kubernetes/services/metallb/

# Apply all services
kubectl apply -k kubernetes/services/
```

**Option 2: Automated (Ansible)**
- Some services are deployed via Ansible (e.g., MetalLB)
- Ansible uses these manifest files as templates
- See individual service READMEs for details

**Option 3: GitOps (Future)**
- Point ArgoCD/Flux at this directory
- Automated sync and drift detection
- Recommended for production

## Directory Conventions

### `services/` - Infrastructure Services

**Purpose**: Core platform services that applications depend on

**Examples**:
- **metallb**: LoadBalancer IP assignment
- **traefik**: Ingress controller / reverse proxy
- **cert-manager**: TLS certificate management (future)
- **longhorn**: Distributed block storage (future)
- **prometheus**: Monitoring and metrics (future)

**Structure**:
```
services/<service-name>/
├── README.md              # Service-specific documentation
├── kustomization.yaml     # Kustomize config for kubectl apply -k
├── <resource>.yaml        # Kubernetes manifests
└── values.yaml           # Helm values (if using Helm)
```

### `apps/` - Application Workloads

**Purpose**: Your custom applications and workloads

**Examples** (future):
- Web applications
- APIs
- Background jobs
- Databases
- Stateful applications

**Structure**:
```
apps/<app-name>/
├── deployment.yaml        # Deployment/StatefulSet
├── service.yaml          # Service definition
├── ingress.yaml          # Ingress routes
├── configmap.yaml        # Configuration
└── kustomization.yaml    # Kustomize config
```

## Services

### MetalLB

**Purpose**: Provides LoadBalancer support for bare-metal clusters

**Status**: ✅ Configured and deployed via Ansible

**Location**: [services/metallb/](services/metallb/)

**Quick Start**:
```bash
# Deploy via Ansible (recommended)
make metallb-install

# Or manually
kubectl apply -k kubernetes/services/metallb/

# Verify
kubectl get ipaddresspool -n metallb-system
kubectl get pods -n metallb-system
```

**Configuration**:
- IP Pool: Configured from Terraform via Ansible inventory
- Mode: Layer 2 (ARP-based)
- See [services/metallb/README.md](services/metallb/README.md)

### Traefik

**Purpose**: Ingress controller and reverse proxy

**Status**: ⚠️ Partial configuration (IngressRoute for dashboard)

**Location**: [services/traefik/](services/traefik/)

**Configuration**:
- `traefik-config.yaml`: IngressRoute for Traefik dashboard
- Access: http://traefik.localhost/dashboard
- Note: K3s includes Traefik by default (disabled in our setup)

## Common Tasks

### Deploy a Service

```bash
# Option 1: Using kustomize
kubectl apply -k kubernetes/services/<service-name>/

# Option 2: Apply all manifests
kubectl apply -f kubernetes/services/<service-name>/

# Option 3: Via Ansible (if available)
make <service>-install
```

### View Service Status

```bash
# List all deployments in a namespace
kubectl get all -n <namespace>

# View pods
kubectl get pods -n metallb-system
kubectl get pods -n traefik

# View services with external IPs
kubectl get svc --all-namespaces | grep LoadBalancer
```

### Update Configuration

```bash
# Edit the manifest
vim kubernetes/services/metallb/ipaddresspool.yaml

# Apply changes
kubectl apply -k kubernetes/services/metallb/

# Verify
kubectl get ipaddresspool -n metallb-system -o yaml
```

### Debug Issues

```bash
# View logs
kubectl logs -n <namespace> <pod-name>
kubectl logs -n metallb-system -l app=metallb

# Describe resource
kubectl describe pod -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Best Practices

### 1. Use Namespaces

Organize services by namespace:
- `metallb-system` - MetalLB components
- `traefik` - Ingress controller
- `cert-manager` - Certificate management
- `monitoring` - Prometheus/Grafana
- `default` or custom - Your applications

### 2. Version Control Everything

All manifests should be:
- ✅ Committed to git
- ✅ Reviewed before applying
- ✅ Tagged with versions/releases

### 3. Use Kustomize

Each service should have `kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: metallb-system
resources:
  - ipaddresspool.yaml
  - l2advertisement.yaml
```

Benefits:
- Apply multiple files with one command
- Namespace/label transformations
- ConfigMap/Secret generators

### 4. Document Configuration

Each service should have:
- `README.md` - Usage and configuration
- Comments in YAML - Explain non-obvious settings
- Examples - Common use cases

### 5. Separate Configuration from Code

Use ConfigMaps and Secrets:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  database.host: postgres.default.svc
  log.level: info
```

## Integration with Infrastructure

### Terraform → Ansible → Kubernetes

```
1. Terraform
   ├── Provisions VMs and networks
   ├── Exports cluster_config.json
   └── Defines IP pools for MetalLB

2. Ansible
   ├── Deploys K3s cluster
   ├── Reads cluster_config.json
   ├── Templates kubernetes manifests
   └── Applies services (MetalLB)

3. Kubernetes Manifests (this directory)
   ├── Single source of truth
   ├── Used by Ansible (templated)
   ├── Used by kubectl (manual)
   └── Used by GitOps (future)
```

### Dynamic vs Static Configuration

**Dynamic** (Templated by Ansible):
- IP pools (from Terraform)
- Node labels/taints
- Cluster-specific settings

**Static** (Version-controlled):
- Service definitions
- Resource limits
- Ingress rules
- Everything else

## Deployed Services

### Core Platform ✅ (Ansible Bootstrap)
Infrastructure services required before GitOps can function:
- [x] **MetalLB** - LoadBalancer IP assignment (192.168.10.150-159)
- [x] **Longhorn** - Distributed block storage with replication
- [x] **Cert-Manager** - Automated TLS certificates via Let's Encrypt
- [x] **Traefik** - Ingress controller with HTTPS (192.168.10.146)
- [x] **ArgoCD** - GitOps continuous delivery platform
- [x] **Sealed Secrets** - Encrypt secrets for safe storage in Git
- [x] **External-DNS** - Automated DNS record management for Cloudflare

### Applications ✅ (ArgoCD GitOps)
Applications managed via GitOps after bootstrap services are ready:
- [x] **Kured** - Automated node reboots during maintenance window (04:00-08:00 UTC)
- [x] **Monitoring Stack** (kube-prometheus-stack)
  - [x] **Grafana** - Metrics dashboards (https://grafana.silverseekers.org)
  - [ ] **Prometheus** - Metrics collection (pending node recovery)
  - [ ] **Alertmanager** - Alert routing (pending node recovery)
  - [x] **Node Exporters** - Node metrics on all nodes
  - [x] **Kube-state-metrics** - Cluster state metrics

## Future Additions

### Networking
- [x] **external-dns** - Automatic DNS record creation (IMPLEMENTED)

### Storage
- [ ] **minio** - S3-compatible object storage
- [ ] **nfs-client-provisioner** - NFS storage class
- [ ] **velero** - Backup and restore

### Observability
- [ ] **loki** - Log aggregation
- [ ] **tempo** - Distributed tracing
- [ ] **jaeger** - Distributed tracing UI

### Security
- [ ] **vault** - Secret management
- [ ] **falco** - Runtime security
- [ ] **trivy** - Vulnerability scanning

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [K3s Documentation](https://docs.k3s.io/)
- [Service Mesh Comparison](https://kubevela.io/docs/platform-engineers/service-mesh/)
