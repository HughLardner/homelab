# Longhorn Storage

Longhorn is a distributed block storage system for Kubernetes that provides persistent volumes for stateful applications.

## Quick Reference

```bash
# Install Longhorn (automated)
make longhorn-install

# Access Longhorn UI
make longhorn-ui

# View storage resources
kubectl get pods -n longhorn-system
kubectl get storageclass
kubectl get pv
kubectl get pvc -A

# Check node storage
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.storage}{"\n"}{end}'
```

## Features

- **Distributed Storage**: Replicates data across multiple nodes
- **Snapshots & Backups**: Point-in-time recovery
- **Volume Expansion**: Dynamically resize volumes
- **High Availability**: Automatic failover
- **Web UI**: Visual management dashboard
- **CSI Compliant**: Standard Kubernetes storage interface

## Configuration

### Storage Settings

**Replica Count**: Number of replicas per volume (default: 2)
- 1 replica = No redundancy (testing only)
- 2 replicas = Survives 1 node failure
- 3 replicas = Survives 2 node failures (recommended for production)

**Data Path**: Storage location on each node (default: `/var/lib/longhorn`)
- Must have sufficient free space
- Recommended: Separate disk/partition from OS

### Service Type

**LoadBalancer** (default): External IP via MetalLB
- Quick access during setup
- Change to ClusterIP after Traefik ingress is configured

**ClusterIP**: Internal only
- Access via kubectl port-forward or Ingress

**NodePort**: Access via node IP + port
- Useful for air-gapped environments

## Installation

### Automated (Ansible)

```bash
# Install Longhorn
make longhorn-install

# Verify installation
kubectl get pods -n longhorn-system
kubectl get storageclass longhorn

# Access UI (LoadBalancer)
LONGHORN_IP=$(kubectl get svc -n longhorn-system longhorn-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open "http://$LONGHORN_IP"
```

### Manual (Helm)

```bash
# Add Helm repository
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Install with custom values
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --values kubernetes/services/longhorn/values.yaml

# Verify
kubectl get pods -n longhorn-system
```

### Manual (kubectl)

```bash
# Apply official manifests
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

# Verify
kubectl get pods -n longhorn-system
```

## Usage

### Create PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### Use in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-app-data
```

### Use in StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: longhorn
      resources:
        requests:
          storage: 20Gi
```

## Common Tasks

### Create Snapshot

```bash
# Via UI: Volumes → Select Volume → Take Snapshot

# Via kubectl
cat <<EOF | kubectl apply -f -
apiVersion: longhorn.io/v1beta1
kind: Snapshot
metadata:
  name: my-snapshot
  namespace: longhorn-system
spec:
  volumeName: pvc-abc123
EOF
```

### Backup Volume

```bash
# Configure backup target in UI:
# Settings → General → Backup Target
# Example: s3://bucket@region/path

# Create backup
# Volumes → Select Volume → Create Backup
```

### Restore from Backup

```bash
# Via UI:
# Backup → Select Backup → Restore

# Creates new volume from backup
```

### Expand Volume

```yaml
# Edit PVC to increase size
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  resources:
    requests:
      storage: 20Gi  # Increased from 10Gi
```

### Access Longhorn UI

```bash
# Via LoadBalancer (if configured)
kubectl get svc -n longhorn-system longhorn-frontend

# Via port-forward
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Via Ingress (after Traefik installed)
# Edit values.yaml: ingress.enabled: true
# Apply: kubectl apply -f kubernetes/services/longhorn/values.yaml
```

## Monitoring

### Check Volume Status

```bash
# List all volumes
kubectl get volumes -n longhorn-system

# Describe specific volume
kubectl describe volume -n longhorn-system pvc-abc123

# Check replica status
kubectl get replicas -n longhorn-system
```

### Check Node Status

```bash
# View nodes in UI: Node → All Nodes

# Via kubectl
kubectl get nodes.longhorn.io -n longhorn-system

# Check disk usage
kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.diskStatus}{"\n"}{end}'
```

### View Events

```bash
# Longhorn events
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'

# Volume events
kubectl describe pvc <pvc-name>
```

## Troubleshooting

### Volume Not Attaching

```bash
# Check volume state
kubectl describe volume -n longhorn-system <volume-name>

# Check replica status
kubectl get replicas -n longhorn-system

# Check node status
kubectl get nodes.longhorn.io -n longhorn-system

# View logs
kubectl logs -n longhorn-system -l app=longhorn-manager
```

### Out of Space

```bash
# Check disk usage
kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.diskStatus.default.storageAvailable}{"\n"}{end}'

# Clean up snapshots
# UI: Volumes → Select Volume → Snapshots → Delete old snapshots

# Adjust over-provisioning
# UI: Settings → Storage Over Provisioning Percentage
```

### Replica Stuck in Rebuilding

```bash
# Check replica logs
kubectl logs -n longhorn-system <replica-pod>

# Force salvage
kubectl edit volume -n longhorn-system <volume-name>
# Set: spec.salvageRequested: true

# Delete stuck replica
kubectl delete replica -n longhorn-system <replica-name>
```

### Pod Stuck in ContainerCreating

```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Check volume attachment
kubectl get volumeattachment

# Check CSI driver
kubectl get csidrivers
kubectl get pods -n longhorn-system -l app=csi-attacher
kubectl get pods -n longhorn-system -l app=csi-provisioner
```

### Uninstall Issues

```bash
# Delete all PVCs first
kubectl delete pvc --all -A

# Wait for volumes to detach
kubectl get volumes -n longhorn-system

# Uninstall Longhorn
kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

# Clean up CRDs if needed
kubectl delete crd $(kubectl get crd | grep longhorn | awk '{print $1}')
```

## Best Practices

### Storage Planning

1. **Separate Storage Disks**: Use dedicated disks for Longhorn data
2. **Storage Requirements**: Plan for 2-3x actual data size (replicas + snapshots)
3. **Node Count**: 1 node for single-node deployment (1 replica), 3+ nodes for HA (2-3 replicas)
4. **Disk Type**: SSDs recommended for production workloads

> **Note**: The current single-node deployment uses 1 replica. To scale to HA, add more nodes and increase replica count.

### Performance Tuning

1. **Local Storage**: Use local SSDs for best performance
2. **Replica Count**: Balance redundancy vs performance (fewer replicas = faster)
3. **Node Affinity**: Co-locate replicas on fast nodes
4. **Snapshot Cleanup**: Remove old snapshots regularly

### Backup Strategy

1. **Backup Target**: Configure S3/NFS backup target
2. **Recurring Backups**: Schedule automatic backups
3. **Test Restores**: Regularly verify backup restoration
4. **Off-site**: Use different region/provider for backups

### High Availability

1. **3+ Nodes**: Minimum for HA setup
2. **3 Replicas**: For critical data
3. **Node Anti-Affinity**: Spread replicas across nodes
4. **Zone Awareness**: Spread across availability zones

## Integration with Ansible

**These manifest files are the single source of truth for Longhorn configuration.**

The Ansible playbook (`ansible/playbooks/longhorn.yml`) uses these files:
- Templates `values.yaml` with variables from inventory
- Applies Longhorn manifests to the cluster

### Configuration Workflow

1. **Initial Deployment** (Automated):
   ```bash
   make longhorn-install  # Ansible templates and applies
   ```

2. **Manual Changes** (Day-2 Operations):
   ```bash
   # Edit configuration
   vim kubernetes/services/longhorn/values.yaml

   # Apply via Helm
   helm upgrade longhorn longhorn/longhorn \
     -n longhorn-system \
     --values kubernetes/services/longhorn/values.yaml

   # Or re-run Ansible
   make longhorn-install
   ```

3. **GitOps** (Future):
   Point ArgoCD/Flux at `kubernetes/services/longhorn/` directory

## Configuration Variables

From Ansible inventory (via Terraform):

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_replica_count` | `2` | Number of replicas per volume |
| `longhorn_data_path` | `/var/lib/longhorn` | Storage path on nodes |
| `longhorn_ui_service_type` | `LoadBalancer` | UI service type |

## References

- [Official Documentation](https://longhorn.io/docs/)
- [Architecture Overview](https://longhorn.io/docs/latest/concepts/)
- [Installation Guide](https://longhorn.io/docs/latest/deploy/install/)
- [Best Practices](https://longhorn.io/docs/latest/best-practices/)
- [Troubleshooting Guide](https://longhorn.io/docs/latest/troubleshooting/)
- [GitHub Repository](https://github.com/longhorn/longhorn)
