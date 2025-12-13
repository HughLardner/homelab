# High Availability Configuration Summary

This document outlines the HA configuration options for the homelab Kubernetes cluster.

## Current Deployment

> **Note**: The current deployment is a **single-node cluster** optimized for low-power hardware (12GB RAM). The HA configurations documented below apply when scaling to a 3-node cluster.

### Single-Node Configuration (Current)
- **1 node** (homelab-node-0 at 192.168.10.20)
- **12GB RAM, 100GB disk**
- **Longhorn** with 1 replica (no replication on single node)
- **All services** running on single node

### Multi-Node HA Configuration (Optional)
To scale to HA, update `terraform/clusters.tf`:
```hcl
node_count = 3
memory = 4096  # 4GB per node
```

## HA Overview (3-Node Cluster)

When running a 3-node cluster, the infrastructure supports:
- **3 control plane nodes** (homelab-node-0, homelab-node-1, homelab-node-2)
- **Embedded etcd** in HA mode across all control planes
- **MetalLB** for LoadBalancer service distribution
- **Longhorn** for distributed storage with replication (2-3 replicas)

The following HA configurations apply to the 3-node deployment.

## Configuration Changes

### 1. ArgoCD GitOps Platform

**File**: `ansible/inventory/hosts.yml`

```yaml
argocd_replicas: 3                    # Server replicas (was: 1)
argocd_controller_replicas: 1         # Controller (stateful, 1 is sufficient)
argocd_repo_replicas: 3               # Repo server replicas (was: 1)
argocd_appset_replicas: 2             # ApplicationSet controller replicas (was: 1)
```

**Impact**:
- ArgoCD UI now survives node failures
- Git repository operations distributed across multiple replicas
- ApplicationSet controller has failover capability

**Note**: The application controller remains at 1 replica as it manages cluster state and uses leader election internally.

### 2. Monitoring Stack (Prometheus, Grafana, Alertmanager)

**File**: `kubernetes/applications/monitoring/values.yaml`

#### Alertmanager
```yaml
alertmanager:
  alertmanagerSpec:
    replicas: 3  # Was: unset (default 1)
```

#### Grafana
```yaml
grafana:
  replicas: 2  # Was: unset (default 1)
```

#### Prometheus
```yaml
prometheus:
  prometheusSpec:
    replicas: 2  # Was: unset (default 1)
```

**Impact**:
- Alert processing continues during node failures
- Grafana dashboards remain accessible
- Prometheus scraping and querying distributed across replicas

### 3. Cert-Manager (TLS Certificate Management)

**File**: `kubernetes/services/cert-manager/values.yaml`

```yaml
replicaCount: 2  # Main controller (was: unset, default 1)

webhook:
  replicaCount: 2  # Webhook (was: unset, default 1)

cainjector:
  replicaCount: 2  # CA injector (was: unset, default 1)
```

**Impact**:
- Certificate issuance and renewal continues during failures
- Webhook validation remains available for certificate resources
- CA certificate injection resilient to node failures

### 4. MetalLB LoadBalancer

**Files**:
- `kubernetes/services/metallb/controller-ha-patch.yaml` (NEW)
- `kubernetes/services/metallb/kustomization.yaml` (UPDATED)

**Patch Content**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller
  namespace: metallb-system
spec:
  replicas: 2  # Was: 1
```

**Impact**:
- LoadBalancer IP assignment survives controller failures
- Multiple controllers compete for leader election
- Service external IPs remain stable during node failures

**Note**: MetalLB speakers remain as a DaemonSet (1 per node), which is correct for L2 mode.

### 5. Sealed Secrets Controller

**File**: `kubernetes/services/sealed-secrets/values.yaml`

```yaml
replicas: 2  # Was: commented out

podDisruptionBudget:
  enabled: true   # Was: false
  minAvailable: 1 # Ensures at least 1 replica available during disruptions
```

**Impact**:
- Secret decryption operations continue during node failures
- Protected from accidental disruption during cluster maintenance
- GitOps workflows can proceed even during rolling updates

### 6. External-DNS (DNS Automation)

**File**: `kubernetes/services/external-dns/values.yaml`

```yaml
replicas: 2  # Was: unset (default 1)

podDisruptionBudget:
  enabled: true   # Ensures at least 1 replica available
  minAvailable: 1

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: external-dns
          topologyKey: kubernetes.io/hostname
```

**Impact**:
- DNS record synchronization continues during node failures
- LoadBalancer IP changes are automatically propagated to Cloudflare
- Leader election ensures only one instance updates DNS at a time
- Service DNS records remain accurate when MetalLB IPs change

**Note**: External-DNS uses leader election internally, so only the active replica performs DNS updates while the standby remains ready for failover.

### 7. CoreDNS Local DNS Server

**Files**:
- `kubernetes/services/coredns-local/etcd/statefulset.yaml`
- `kubernetes/services/coredns-local/coredns/deployment.yaml`
- `kubernetes/services/external-dns-local/values.yaml`

#### etcd (DNS Record Storage)

```yaml
replicas: 3  # Quorum-based consensus

podDisruptionBudget:
  minAvailable: 2  # Can tolerate 1 node failure

persistence:
  storageClassName: longhorn
  size: 1Gi  # Per replica

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: coredns-etcd
          topologyKey: kubernetes.io/hostname
```

**Impact**:
- Raft consensus protocol ensures data consistency
- 3 replicas provide quorum (can tolerate 1 failure)
- Longhorn persistence ensures data survives pod restarts
- Anti-affinity spreads replicas across nodes

#### CoreDNS (DNS Server)

```yaml
replicas: 2  # High availability

podDisruptionBudget:
  enabled: true
  minAvailable: 1

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: coredns
          topologyKey: kubernetes.io/hostname
```

**Impact**:
- Local DNS continues serving during node failures
- LoadBalancer IP (192.168.10.150) remains accessible
- DNS queries work even when one CoreDNS pod is down
- Offline resilience - works without internet

#### External-DNS Local (CoreDNS Provider)

```yaml
replicas: 2  # High availability

podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Leader election enabled (only active instance updates DNS)
```

**Impact**:
- Automatic DNS updates continue during node failures
- Leader election ensures only one instance updates etcd
- Standby replica takes over if leader fails

### 8. Already HA-Configured Services

These services were already properly configured for HA:

#### Traefik Ingress Controller
```yaml
traefik_replicas: 2
```

#### Longhorn Storage (CSI Components)
```yaml
csi:
  attacherReplicaCount: 3
  provisionerReplicaCount: 3
  resizerReplicaCount: 3
  snapshotterReplicaCount: 3
```

## Services Intentionally Not HA

Some services remain single-replica by design:

### Redis (ArgoCD)
- Used only for caching
- Not critical path for ArgoCD operations
- Acceptable to lose cache during failures

### Longhorn Manager
- Runs as DaemonSet (1 per node)
- Distributed by nature
- No need for additional replicas

## Deployment Order

When applying these changes, follow this order:

### Option 1: Full Cluster Rebuild
```bash
# 1. Update configuration in Git
git add ansible/inventory/hosts.yml
git add kubernetes/services/
git add kubernetes/applications/monitoring/
git commit -m "Configure HA for all services"

# 2. Redeploy from scratch
cd ansible
make cluster-destroy  # Careful!
make cluster-deploy
```

### Option 2: Rolling Update (Recommended)

```bash
# 1. Update MetalLB controller
cd kubernetes/services/metallb
kubectl apply -k .

# 2. Update cert-manager
cd ../cert-manager
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --values values.yaml

# 3. Update sealed-secrets
cd ../sealed-secrets
helm upgrade sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --values values.yaml

# 4. Update monitoring stack
cd ../../applications/monitoring
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values.yaml

# 5. Update ArgoCD (requires Ansible run)
cd ../../../../ansible
ansible-playbook playbooks/argocd.yml
```

### Option 3: GitOps via ArgoCD (Best Practice)

If using ArgoCD to manage these services:

```bash
# Commit changes to Git
git add .
git commit -m "Configure HA for all services"
git push

# Sync via ArgoCD
argocd app sync root-app --cascade
```

## Verification

After applying changes, verify HA is working:

```bash
# Check replica counts
kubectl get deployment -A | grep -E 'READY|argocd|cert-manager|metallb|sealed-secrets|grafana|prometheus|alertmanager'

# Expected output (example):
# NAMESPACE         NAME                      READY   UP-TO-DATE   AVAILABLE
# argocd            argocd-server             3/3     3            3
# argocd            argocd-repo-server        3/3     3            3
# cert-manager      cert-manager              2/2     2            2
# cert-manager      cert-manager-webhook      2/2     2            2
# cert-manager      cert-manager-cainjector   2/2     2            2
# kube-system       sealed-secrets-controller 2/2     2            2
# metallb-system    controller                2/2     2            2
# monitoring        monitoring-grafana        2/2     2            2
# traefik           traefik                   2/2     2            2

# Check StatefulSets
kubectl get statefulset -A

# Expected:
# monitoring        alertmanager-kube-prometheus-alertmanager   3/3
# monitoring        prometheus-kube-prometheus-prometheus       2/2
```

## Testing Failover

To test HA configuration, simulate a node failure:

```bash
# Identify a node running critical pods
kubectl get pods -A -o wide | grep argocd-server

# Drain the node (graceful)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Verify services remain available
curl -k https://argocd.silverseekers.org  # Should still work
curl -k https://traefik.silverseekers.org # Should still work

# Check pod rescheduling
kubectl get pods -A -o wide | grep argocd-server

# Uncordon node when done
kubectl uncordon <node-name>
```

## Resource Impact

With these HA changes, the cluster resource usage increases:

### CPU Requests (approximate increase)
- ArgoCD: +200m (2 additional replicas)
- Monitoring: +400m (Prometheus +250m, Alertmanager +100m, Grafana +50m)
- Cert-manager: +30m (3 additional replicas)
- Sealed-secrets: +50m (1 additional replica)
- MetalLB: +10m (1 additional controller)
- CoreDNS Local: +600m (etcd 3x100m, CoreDNS 2x50m, external-dns-local 2x50m)
- **Total: ~1.3 CPU (1300m)**

### Memory Requests (approximate increase)
- ArgoCD: +384Mi
- Monitoring: +896Mi (Prometheus +512Mi, Alertmanager +256Mi, Grafana +128Mi)
- Cert-manager: +96Mi
- Sealed-secrets: +64Mi
- MetalLB: +50Mi
- CoreDNS Local: +512Mi (etcd 3x128Mi, CoreDNS 2x64Mi, external-dns-local 2x64Mi)
- **Total: ~2Gi Memory**

### Storage (Longhorn)
- CoreDNS Local (etcd): +3Gi (3 replicas x 1Gi each)

### Cluster Capacity
With 3 nodes @ 2 CPU / 4Gi each:
- Total capacity: 6 CPU / 12Gi
- HA overhead: ~22% CPU / ~17% Memory
- **Acceptable for production homelab**

## Anti-Affinity Considerations

For true HA, consider adding pod anti-affinity rules to ensure replicas are spread across nodes:

```yaml
# Example for ArgoCD server
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app.kubernetes.io/name: argocd-server
        topologyKey: kubernetes.io/hostname
```

This ensures multiple replicas don't land on the same node. Consider implementing this in future iterations.

## Maintenance Windows

With HA properly configured, you can now:

1. **Rolling node updates**: Drain and reboot nodes one at a time
2. **Zero-downtime upgrades**: Update applications without service interruption
3. **Cluster maintenance**: Perform maintenance during business hours
4. **Chaos testing**: Validate resilience with controlled failures

## Next Steps

1. ✅ Apply HA configuration changes
2. ✅ Verify all services have multiple replicas
3. 🔲 Test failover by draining a node
4. 🔲 Implement pod anti-affinity rules
5. 🔲 Set up monitoring alerts for replica health
6. 🔲 Document runbook for handling node failures
7. 🔲 Consider implementing PodDisruptionBudgets for all HA services

## References

- [Kubernetes Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [ArgoCD High Availability](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
- [Prometheus High Availability](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#alertmanager_config)
- [MetalLB Configuration](https://metallb.universe.tf/configuration/)

---

**Last Updated**: 2025-12-13
**Author**: Claude Code
**Cluster**: homelab (single-node, scalable to HA)
