# CoreDNS Local DNS Server

**Automated local DNS management for the homelab cluster**

## Overview

This directory contains the configuration for a **local DNS server** that provides automatic DNS management for your homelab cluster. It eliminates the need for manual DNS entries and works even when the internet is down.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│          Kubernetes Cluster (coredns-local)             │
│                                                          │
│  External-DNS (watches K8s resources)                   │
│       ↓                                                  │
│  etcd (stores DNS records in SkyDNS format)             │
│       ↓                                                  │
│  CoreDNS (serves DNS queries from etcd)                 │
│       ↓                                                  │
│  LoadBalancer: 192.168.10.150                           │
└──────────────────┬───────────────────────────────────────┘
                   │
                   ↓
           ┌───────────────┐
           │ Local Network │
           │    Devices    │
           └───────────────┘
```

### Components

1. **etcd** (3 replicas): Backend storage for DNS records
2. **CoreDNS** (2 replicas): DNS server that reads from etcd
3. **External-DNS** (2 replicas): Watches Kubernetes and updates etcd
4. **LoadBalancer**: MetalLB assigns 192.168.10.150

## Features

✅ **Fully Automated**: DNS records automatically created/updated when services change
✅ **Offline Resilient**: Works without internet connection
✅ **High Availability**: All components run with multiple replicas
✅ **Zero Manual Entries**: No manual DNS configuration needed
✅ **Fast Queries**: Local DNS is faster than external DNS

## How It Works

### Automatic DNS Management

When you deploy a Service with LoadBalancer type or an IngressRoute:

```yaml
# Example: Traefik Service
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "traefik.silverseekers.org"
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.10.145
```

**What happens automatically:**
1. External-DNS detects the new service
2. External-DNS creates a record in etcd: `/skydns/org/silverseekers/traefik`
3. CoreDNS reads the record from etcd
4. DNS queries for `traefik.silverseekers.org` return `192.168.10.145`

**When the IP changes:**
1. MetalLB assigns new IP (e.g., 192.168.10.151)
2. External-DNS updates the record in etcd
3. CoreDNS automatically serves the new IP
4. No manual intervention needed!

### DNS Resolution Flow

**Local Device Query**:
```
Device → CoreDNS (192.168.10.150)
    ↓
CoreDNS checks etcd for silverseekers.org records
    ↓
Returns: 192.168.10.145
    ↓
Device connects directly to service
```

**Unknown Domain Query**:
```
Device → CoreDNS (192.168.10.150)
    ↓
CoreDNS forwards to Cloudflare (1.1.1.1)
    ↓
Returns: External IP
```

## Installation

### Prerequisites

- ✅ K3s cluster running
- ✅ MetalLB configured with IP pool
- ✅ Longhorn storage for etcd persistence
- ✅ External-DNS (Cloudflare) already deployed

### Option 1: Via Ansible (Recommended)

```bash
# Deploy complete stack
make coredns-local-install

# Check status
make coredns-local-status

# Test DNS resolution
make coredns-local-test
```

### Option 2: Via kubectl

```bash
# Apply all resources
kubectl apply -k kubernetes/services/coredns-local/

# Wait for etcd cluster to form
kubectl wait --for=condition=ready pod -l app=coredns-etcd -n coredns-local --timeout=300s

# Wait for CoreDNS
kubectl wait --for=condition=ready pod -l app=coredns -n coredns-local --timeout=300s

# Deploy external-dns-local
kubectl apply -f kubernetes/applications/external-dns-local/application.yaml
```

### Option 3: Via ArgoCD (GitOps)

```bash
# Deploy CoreDNS infrastructure
kubectl apply -k kubernetes/services/coredns-local/

# Deploy external-dns via ArgoCD
kubectl apply -f kubernetes/applications/external-dns-local/application.yaml

# Monitor sync
make apps-status
```

## Configuration

### Router/DHCP Setup

**After deployment**, configure your router to use the local DNS:

```
Primary DNS:   192.168.10.150  (CoreDNS on cluster)
Secondary DNS: 1.1.1.1         (Cloudflare fallback)
```

**DHCP Option 6** (DNS Server):
- Primary: 192.168.10.150
- Secondary: 1.1.1.1

### Verification

```bash
# Check CoreDNS LoadBalancer IP
kubectl get svc -n coredns-local coredns

# Should show:
# NAME      TYPE           EXTERNAL-IP       PORT(S)
# coredns   LoadBalancer   192.168.10.150    53:xxxxx/UDP,53:xxxxx/TCP

# Test DNS query
nslookup argocd.silverseekers.org 192.168.10.150

# Should return:
# Server:    192.168.10.150
# Address:   192.168.10.150#53
#
# Name:      argocd.silverseekers.org
# Address:   192.168.10.145
```

## Operations

### Check Component Status

```bash
# etcd cluster
kubectl get statefulset -n coredns-local coredns-etcd
kubectl get pods -n coredns-local -l app=coredns-etcd

# CoreDNS
kubectl get deployment -n coredns-local coredns
kubectl get svc -n coredns-local coredns

# External-DNS (local)
kubectl get deployment -n external-dns-local external-dns-local
kubectl get pods -n external-dns-local
```

### View Logs

```bash
# CoreDNS logs
kubectl logs -n coredns-local -l app=coredns --tail=50 -f

# External-DNS logs
kubectl logs -n external-dns-local -l app.kubernetes.io/name=external-dns --tail=50 -f

# etcd logs
kubectl logs -n coredns-local coredns-etcd-0
```

### Inspect etcd Records

```bash
# Open etcd shell
kubectl exec -it -n coredns-local coredns-etcd-0 -- sh

# List all DNS records
etcdctl get /skydns --prefix --keys-only

# Get specific record
etcdctl get /skydns/org/silverseekers/argocd

# Example output:
# {"host":"192.168.10.145","ttl":300}
```

### Manual DNS Testing

```bash
# Test from local machine
dig @192.168.10.150 argocd.silverseekers.org +short

# Test from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup argocd.silverseekers.org 192.168.10.150
```

## Troubleshooting

### DNS Queries Not Working

```bash
# Check CoreDNS pods are running
kubectl get pods -n coredns-local -l app=coredns

# Check CoreDNS logs for errors
kubectl logs -n coredns-local -l app=coredns --tail=100

# Verify etcd is accessible
kubectl exec -n coredns-local -it coredns-etcd-0 -- etcdctl endpoint health

# Check LoadBalancer IP assigned
kubectl get svc -n coredns-local coredns
```

### Records Not Updating

```bash
# Check external-dns-local is running
kubectl get pods -n external-dns-local

# Check external-dns logs
kubectl logs -n external-dns-local -l app.kubernetes.io/name=external-dns --tail=200

# Look for CREATE/UPDATE operations
kubectl logs -n external-dns-local -l app.kubernetes.io/name=external-dns | grep -E "CREATE|UPDATE"

# Verify external-dns can reach etcd
kubectl exec -n external-dns-local -it <pod-name> -- \
  wget -qO- http://coredns-etcd-client.coredns-local.svc.cluster.local:2379/health
```

### etcd Cluster Issues

```bash
# Check etcd cluster health
kubectl exec -n coredns-local coredns-etcd-0 -- etcdctl endpoint health

# Check cluster members
kubectl exec -n coredns-local coredns-etcd-0 -- etcdctl member list

# Check quorum
kubectl get pods -n coredns-local -l app=coredns-etcd
# Should show 3/3 READY
```

### LoadBalancer IP Not Assigned

```bash
# Check MetalLB controller
kubectl get pods -n metallb-system -l app=metallb,component=controller

# Check MetalLB IP pool
kubectl get ipaddresspool -n metallb-system

# Verify IP 192.168.10.150 is in pool range
kubectl get ipaddresspool -n metallb-system -o yaml | grep -A 5 addresses

# Check service events
kubectl describe svc -n coredns-local coredns
```

## High Availability

### etcd (3 Replicas)

**Configuration**:
- Raft consensus protocol (quorum-based)
- Longhorn persistent volumes (1Gi per replica)
- Pod anti-affinity (spread across nodes)
- PodDisruptionBudget (minAvailable: 2)

**Tolerance**: Can lose 1 node without data loss

### CoreDNS (2 Replicas)

**Configuration**:
- Stateless deployment
- Pod anti-affinity (spread across nodes)
- PodDisruptionBudget (minAvailable: 1)

**Tolerance**: Can lose 1 node and continue serving DNS

### External-DNS (2 Replicas)

**Configuration**:
- Leader election (only active leader updates DNS)
- Pod anti-affinity (spread across nodes)
- PodDisruptionBudget (minAvailable: 1)

**Tolerance**: Standby takes over if leader fails

## Resource Usage

### Per Component

**etcd** (per replica):
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 512Mi limit
- Storage: 1Gi persistent volume

**CoreDNS** (per replica):
- CPU: 50m request, 200m limit
- Memory: 64Mi request, 256Mi limit

**External-DNS** (per replica):
- CPU: 50m request, 200m limit
- Memory: 64Mi request, 128Mi limit

### Total Additional Resources

**CPU**: ~600m (0.6 cores)
**Memory**: ~1.5Gi
**Storage**: 3Gi (Longhorn)

## Monitoring

### Metrics Available

**CoreDNS**:
- Query rate
- Query latency
- Error rate
- Cache hit rate

**etcd**:
- Leader status
- Consensus health
- Storage usage
- Request latency

**External-DNS**:
- Sync operations
- Error rate
- Records managed

### Prometheus Queries

```promql
# CoreDNS query rate
rate(coredns_dns_requests_total{job="coredns"}[5m])

# CoreDNS cache hit ratio
sum(rate(coredns_cache_hits_total[5m])) / sum(rate(coredns_dns_requests_total[5m]))

# etcd leader status
etcd_server_has_leader

# External-DNS sync success rate
rate(external_dns_registry_errors_total[5m])
```

## Security

### Network Access

**etcd**: Only accessible within cluster (ClusterIP services)
**CoreDNS**: Exposed on LoadBalancer (DNS queries only)
**External-DNS**: Internal only (updates etcd)

### RBAC

- CoreDNS: Read-only access to Services/Endpoints
- External-DNS: Read Services/IngressRoutes, write to etcd
- etcd: No authentication (cluster-internal only)

### Optional: Enable etcd Authentication

```bash
# Create root user
kubectl exec -n coredns-local coredns-etcd-0 -- etcdctl user add root

# Enable authentication
kubectl exec -n coredns-local coredns-etcd-0 -- etcdctl auth enable

# Update CoreDNS and external-dns configs with credentials
```

## Backup and Recovery

### Backup etcd

```bash
# Manual snapshot
kubectl exec -n coredns-local coredns-etcd-0 -- \
  etcdctl snapshot save /tmp/snapshot.db

# Copy snapshot out
kubectl cp coredns-local/coredns-etcd-0:/tmp/snapshot.db ./etcd-backup.db
```

### Restore from Snapshot

```bash
# Scale down etcd
kubectl scale statefulset -n coredns-local coredns-etcd --replicas=0

# Copy snapshot into pod
kubectl cp ./etcd-backup.db coredns-local/coredns-etcd-0:/tmp/snapshot.db

# Restore
kubectl exec -n coredns-local coredns-etcd-0 -- \
  etcdctl snapshot restore /tmp/snapshot.db --data-dir=/var/etcd/data

# Scale up
kubectl scale statefulset -n coredns-local coredns-etcd --replicas=3
```

### Automated Backups

**TODO**: Create CronJob for automated etcd backups to Longhorn

## Comparison: Before vs After

### Before (Manual DNS)

❌ Manual DNS entries in router/Pi-hole
❌ Stale entries when IPs change
❌ Services inaccessible after IP changes
⚠️ Internet dependency for DNS

### After (Automated Local DNS)

✅ Fully automated DNS management
✅ Always up-to-date records
✅ Services accessible even when IPs change
✅ Works without internet connection
✅ Fast local DNS resolution

## Integration with External-DNS (Cloudflare)

### Dual DNS Strategy

**Local Network**:
- Devices use 192.168.10.150 (CoreDNS)
- External-DNS (CoreDNS provider) manages local DNS
- Works offline

**Remote Access**:
- Devices use Cloudflare DNS (1.1.1.1)
- External-DNS (Cloudflare provider) manages remote DNS
- Works via VPN

### How Both Work Together

```
Kubernetes Service Changed
    ↓
    ├─→ External-DNS (Cloudflare) → Updates Cloudflare DNS
    └─→ External-DNS (CoreDNS) → Updates etcd → CoreDNS serves

Both DNS systems stay in sync automatically!
```

## Future Enhancements

- [ ] Automated etcd backups to Longhorn
- [ ] Grafana dashboard for DNS metrics
- [ ] Alerting for etcd cluster health
- [ ] Custom DNS zones (e.g., `*.internal.home`)
- [ ] DNS query filtering (ad blocking)
- [ ] DNSSEC signing

## References

- [CoreDNS Documentation](https://coredns.io/)
- [CoreDNS etcd Plugin](https://coredns.io/plugins/etcd/)
- [External-DNS CoreDNS Provider](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/coredns.md)
- [etcd Documentation](https://etcd.io/docs/)
- [SkyDNS Format](https://github.com/skynetservices/skydns)

---

**Last Updated**: 2025-12-07
**Author**: Claude Code
**Status**: Production Ready
