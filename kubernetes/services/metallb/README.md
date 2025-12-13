# MetalLB Configuration

MetalLB provides LoadBalancer support for bare-metal Kubernetes clusters.

## Quick Reference

```bash
# View current configuration
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Apply configuration changes
kubectl apply -k kubernetes/services/metallb/

# Or apply individual files
kubectl apply -f kubernetes/services/metallb/ipaddresspool.yaml
kubectl apply -f kubernetes/services/metallb/l2advertisement.yaml

# Check MetalLB status
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb -l component=controller
```

## Configuration Files

### `ipaddresspool.yaml`
Defines IP address pools that MetalLB can assign to LoadBalancer services.

**Default Pool**: `192.168.10.150/28` (IPs: 150-165, 16 addresses)

**Key Fields**:
- `addresses`: IP ranges in CIDR or range notation
- `autoAssign`: Whether to automatically assign IPs from this pool
- `serviceAllocation`: Optional restrictions by namespace/priority

### `l2advertisement.yaml`
Configures Layer 2 (ARP/NDP) advertisement for IP addresses.

**Default**: Advertises all IPs from `default-pool` via all nodes

**Key Fields**:
- `ipAddressPools`: Which pools to advertise
- `nodeSelectors`: Restrict to specific nodes
- `interfaces`: Restrict to specific network interfaces

### `kustomization.yaml`
Kustomize configuration for deploying all MetalLB configs together.

## Common Tasks

### Add a New IP Pool

1. Edit `ipaddresspool.yaml` and add:

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: my-new-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.170-192.168.10.179
  autoAssign: true
```

2. Apply changes:
```bash
kubectl apply -f kubernetes/services/metallb/ipaddresspool.yaml
```

### Request Specific IP for a Service

Add annotation to your service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.10.150
spec:
  type: LoadBalancer
  # ...
```

### Request IP from Specific Pool

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    metallb.universe.tf/address-pool: production-pool
spec:
  type: LoadBalancer
  # ...
```

### Share IP Between Services

Useful for Ingress + other services on same IP:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  annotations:
    metallb.universe.tf/allow-shared-ip: "shared-key"
spec:
  type: LoadBalancer
  # ...
---
apiVersion: v1
kind: Service
metadata:
  name: other-service
  annotations:
    metallb.universe.tf/allow-shared-ip: "shared-key"  # Same key = shared IP
spec:
  type: LoadBalancer
  # ...
```

## Advanced Configurations

### BGP Mode (Future Use)

For production environments with BGP routing, create `bgp-config.yaml`:

```yaml
apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: router
  namespace: metallb-system
spec:
  myASN: 64500
  peerASN: 64501
  peerAddress: 192.168.10.1
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgp-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
```

### Node-Specific Pools

Restrict pool to specific nodes (e.g., edge/ingress nodes):

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: edge-only
  namespace: metallb-system
spec:
  ipAddressPools:
  - edge-pool
  nodeSelectors:
  - matchLabels:
      node-role.kubernetes.io/edge: ""
```

## Troubleshooting

### Check IP Assignments

```bash
# View all LoadBalancer services and their IPs
kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# Check MetalLB logs
kubectl logs -n metallb-system -l component=controller --tail=50
kubectl logs -n metallb-system -l component=speaker --tail=50
```

### IP Not Assigned

Common causes:
1. **No IPs available in pool**: Check if all IPs are exhausted
2. **AutoAssign disabled**: Pool requires manual selection via annotation
3. **Service in wrong namespace**: Pool has `serviceAllocation.namespaces` restriction
4. **MetalLB pods not running**: Check pod status

### Network Connectivity Issues

```bash
# Check ARP entries on nodes
kubectl exec -n metallb-system <speaker-pod> -- ip neigh

# Verify speaker is running on all nodes
kubectl get pods -n metallb-system -o wide -l component=speaker

# Check node network interfaces
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
```

## Integration with Ansible

**These manifest files are the single source of truth for MetalLB configuration.**

The Ansible playbook (`ansible/playbooks/metallb.yml`) uses these files:
- Templates `ipaddresspool.yaml` with the dynamic IP pool from inventory (`metallb_ipv4_pools`)
- Copies `l2advertisement.yaml` as-is
- Applies both to the cluster

### Configuration Workflow

1. **Initial Deployment** (Automated):
   ```bash
   make metallb-install  # Ansible templates and applies these files
   ```

2. **Manual Changes** (Day-2 Operations):
   ```bash
   # Edit the files in kubernetes/services/metallb/
   vim kubernetes/services/metallb/ipaddresspool.yaml

   # Apply changes directly
   kubectl apply -k kubernetes/services/metallb/

   # Or re-run Ansible (for IP pool changes from inventory)
   make metallb-install
   ```

3. **GitOps** (Future):
   Point ArgoCD/Flux at `kubernetes/services/metallb/` directory

**Benefits of single source of truth:**
- ✅ One place to modify configuration
- ✅ Version-controlled manifests
- ✅ Works with both automation and manual ops
- ✅ GitOps-ready

## References

- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [MetalLB Configuration Reference](https://metallb.universe.tf/configuration/)
- [L2 Mode Documentation](https://metallb.universe.tf/concepts/layer2/)
- [BGP Mode Documentation](https://metallb.universe.tf/concepts/bgp/)
