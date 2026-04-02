# Kured (Kubernetes Reboot Daemon)

Kured handles automated, safe node reboots after kernel updates. It ensures nodes are rebooted gracefully within maintenance windows, with proper pod draining and coordination.

## Overview

Kured watches for the `/var/run/reboot-required` sentinel file (created by `apt` on Ubuntu/Debian after kernel updates) and orchestrates safe node reboots during configured maintenance windows.

**Key Features:**
- Automated detection of pending kernel reboots
- Maintenance window enforcement (only reboots during allowed times)
- Graceful pod draining before reboot
- Concurrency control (reboot one node at a time)
- Prometheus metrics for monitoring

## Deployment

### GitOps (Automatic)

Kured is deployed automatically via the ArgoCD root-app (app-of-apps pattern). Once you push this directory to git, ArgoCD will:

1. Detect `kubernetes/services/kured/application.yaml`
2. Add kubereboot Helm repository
3. Deploy kured DaemonSet to kube-system namespace
4. Configure from `values.yaml`
5. Monitor and self-heal automatically

**No manual deployment needed** - just push to git and wait ~3 minutes for ArgoCD to sync.

### Manual Deployment (Optional)

For immediate deployment without waiting for ArgoCD's sync interval:

```bash
# Manually trigger deployment via ArgoCD
make kured-deploy

# Check status
make kured-status

# View logs
make kured-logs
```

**Note:** This is optional - the root-app will deploy kured automatically after it's pushed to git.

## Configuration

**File:** `kubernetes/services/kured/values.yaml`

**Key settings:**

```yaml
configuration:
  # Maintenance window (Europe/Dublin local time)
  startTime: "03:00"
  endTime: "05:00"
  timeZone: "Europe/Dublin"

  # Check period
  period: "15m"         # Check every 15 minutes

  # Reboot delay
  rebootDelay: "1m"     # Wait 60s before reboot

  # Bound drain time on a single-node cluster
  drainTimeout: "10m"
  skipWaitForDeleteTimeout: "60"

  # Concurrency
  concurrency: 1        # Only 1 node reboots at a time

  # Sentinel file
  rebootSentinel: "/var/run/reboot-required"
```

**Maintenance Window:**
- Default: 03:00-05:00 Europe/Dublin local time
- Kubernetes nodes will ONLY reboot during this window
- The 2-hour window is intentional: it covers the 15-minute check cadence,
  bounded drain time, reboot, and post-boot recovery
- Updates detected outside the window wait until next window

## How It Works

1. **System updates create sentinel:**
   ```bash
   # On Ubuntu/Debian, apt creates this file after kernel updates
   sudo apt upgrade
   # → Creates /var/run/reboot-required
   ```

2. **Kured detects sentinel:**
   - Checks every 15 minutes (configurable)
   - Finds `/var/run/reboot-required` on node

3. **Waits for maintenance window:**
   - If outside window (e.g., 2pm), waits until 4am UTC
   - If inside window, proceeds immediately

4. **Acquires reboot lock:**
   - Prevents multiple nodes rebooting simultaneously
   - On single-node clusters, ensures only coordination

5. **Cordons node:**
   ```bash
   kubectl cordon homelab-node-0
   ```
   - Prevents new pods from scheduling

6. **Drains node:**
   ```bash
   kubectl drain homelab-node-0 --ignore-daemonsets --delete-emptydir-data
   ```
   - Gracefully evicts pods (respects PodDisruptionBudgets)
   - DaemonSets remain (kured, kube-proxy, etc.)
   - In this repo, the drain is bounded to 10 minutes so a failed eviction
     cannot leave the only node cordoned forever

7. **Reboots node:**
   ```bash
   systemctl reboot
   ```

8. **Node comes back online:**
   - Kubelet rejoins cluster
   - Kured uncordons node
   - Pods reschedule automatically

## Monitoring

### Check Status

```bash
# DaemonSet
kubectl get daemonset -n kube-system kured

# Pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured

# Configuration
kubectl get daemonset -n kube-system kured -o jsonpath='{.spec.template.spec.containers[0].command}' | tr ',' '\n'
```

### Check Pending Reboots

```bash
# Check for nodes with reboot-required file
ssh ubuntu@192.168.10.20 "ls -la /var/run/reboot-required" 2>/dev/null && echo "Reboot pending" || echo "No reboot pending"

# Check kured annotations
kubectl get nodes -o custom-columns=NAME:.metadata.name,REBOOT:.metadata.annotations.weave\.works/kured-reboot-in-progress
```

### Logs

```bash
# Follow logs
make kured-logs

# Or directly
kubectl logs -n kube-system -l app.kubernetes.io/name=kured -f
```

**Log patterns:**

```
# Normal operation
level=info msg="Kubernetes Reboot Daemon: 1.15.1"
level=info msg="Node ID: homelab-node-0"
level=info msg="Lock Annotation: weave.works/kured-node-lock"
level=info msg="Reboot Sentinel: /var/run/reboot-required"
level=info msg="Prefer No Schedule Taint: "
level=info msg="Blocking Pod Selectors: []"
level=info msg="Reboot on: Mon-Sun between 04:00 and 08:00"
level=info msg="Concurrency: 1"

# Reboot required but outside window
level=info msg="Reboot required, but not within timewindow"

# Reboot starting (inside window)
level=info msg="Reboot required"
level=info msg="Acquired reboot lock"
level=info msg="Cordoning homelab-node-0"
level=info msg="Draining homelab-node-0"
level=info msg="Rebooting node"
```

## Testing

### Manually Trigger Reboot (for testing)

```bash
# Create sentinel file on node
ssh ubuntu@192.168.10.20 "sudo touch /var/run/reboot-required"

# Kured will detect on next check (within 15 minutes)
# Reboot will occur during next maintenance window (03:00-05:00 Europe/Dublin)
```

### Dry Run Mode (annotate only, don't reboot)

Edit `values.yaml`:

```yaml
configuration:
  extraArgs:
    annotate-nodes: "true"  # Only annotate, don't reboot
```

Then redeploy:
```bash
kubectl -n argocd patch application kured --type merge -p '{"operation":{"sync":{}}}'
```

## Prometheus Metrics

Kured exposes metrics on port 8080:

```bash
# Port-forward to access metrics
kubectl port-forward -n kube-system daemonset/kured 8080:8080

# View metrics
curl http://localhost:8080/metrics
```

**Key metrics:**

- `kured_reboot_required` - Node requires reboot (1=yes, 0=no)
- `kured_reboot_duration_seconds` - Time taken to reboot

**Victoria Metrics scraping** (if enabled):

```yaml
# In values.yaml
serviceMonitor:
  create: true
  namespace: monitoring
```

## Single-Node Cluster Considerations

**Current setup (single node):**
- Concurrency: 1 (only node reboots)
- During reboot: brief full-cluster downtime is expected
- Drain is bounded to 10 minutes before kured proceeds with reboot
- All non-DaemonSet pods restart after the node comes back

**Impact:**
- Home automation may be unavailable during reboot
- Monitoring gaps during reboot window
- Longhorn volumes reconnect after boot, but there is no zero-downtime failover

**Single-node safeguards in this repo:**
- Traefik and Sealed Secrets do not use blocking PodDisruptionBudgets
- Longhorn uses `always-allow` node drain policy when `infrastructure.node_count == 1`
- If the node still fails to drain cleanly, the bounded timeout prevents an indefinite `SchedulingDisabled` state

**Multi-node future:**
- Concurrency: 1 (one node at a time)
- Zero-downtime reboots (pods migrate to other nodes)
- Consider PodDisruptionBudgets for critical services

## Troubleshooting

### Kured Not Detecting Reboot

**Check sentinel file exists:**
```bash
ssh ubuntu@192.168.10.20 "ls -la /var/run/reboot-required"
```

**Check kured is running:**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured
```

**Check kured logs for errors:**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=kured --tail=50
```

### Reboot Not Happening During Window

**Check current time vs maintenance window:**
```bash
# Current local time used by kured
TZ=Europe/Dublin date

# Maintenance window: 03:00-05:00 Europe/Dublin
```

**Check if another node has lock:**
```bash
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, lock: .metadata.annotations["weave.works/kured-node-lock"]}'
```

**Check kured logs for "not within timewindow" message:**
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=kured | grep -i window
```

### Node Stuck Draining

**Check which pods are blocking drain:**
```bash
kubectl get pods -A --field-selector spec.nodeName=homelab-node-0
```

**Check PodDisruptionBudgets:**
```bash
kubectl get pdb -A
```

**Check whether the node is still cordoned:**
```bash
kubectl get nodes
kubectl describe node homelab-node-0 | rg "Unschedulable|Taints" -A2 -B1
```

**Check recent scheduling failures:**
```bash
kubectl get events -A --sort-by=.lastTimestamp | rg "FailedScheduling|unschedulable|Preemption"
```

**Force reboot (emergency only):**
```bash
# Via Proxmox console
qm reboot 120

# Or SSH
ssh ubuntu@192.168.10.20 "sudo reboot now"
```

## Configuration Changes

**To change maintenance window:**

1. Edit `kubernetes/services/kured/values.yaml`:
   ```yaml
   configuration:
     startTime: "02:00"
     endTime: "04:00"
     timeZone: "Europe/Dublin"
   ```

2. Commit and push changes

3. ArgoCD will automatically sync (or trigger manually):
   ```bash
   kubectl -n argocd patch application kured --type merge -p '{"operation":{"sync":{}}}'
   ```

**To disable kured:**

Delete the ArgoCD Application:
```bash
kubectl delete application kured -n argocd
```

Or set `concurrency: 0` in values.yaml to pause reboots.

## References

- [Kured Documentation](https://github.com/kubereboot/kured)
- [Kured Helm Chart](https://github.com/kubereboot/charts/tree/main/charts/kured)
- Maintenance window: 03:00-05:00 Europe/Dublin
- Reboot sentinel: `/var/run/reboot-required` (created by apt)
- ArgoCD Application: `kubernetes/services/kured/application.yaml`
- Configuration: `kubernetes/services/kured/values.yaml`
