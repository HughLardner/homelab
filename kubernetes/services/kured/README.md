# Kured (Kubernetes Reboot Daemon)

Automated, safe node reboot management for Kubernetes clusters after system updates.

## Overview

**Kured** (Kubernetes Reboot Daemon) is a DaemonSet that automatically reboots nodes when they require a reboot after system updates (kernel updates, security patches, etc.). It ensures only one node reboots at a time and properly drains pods before rebooting.

**Key Features:**
- 🔄 Automatic node reboots after updates
- ⏰ Time-windowed maintenance (04:00-08:00 UTC)
- 🎯 One node at a time (controlled rollout)
- 🛡️ Proper pod draining before reboot
- 🔔 Optional Slack notifications
- 📊 Prometheus metrics

## Status

**Deployment Status**: ✅ Deployed

**Configuration:**
- **Namespace**: kube-system
- **Chart Version**: Latest (kubereboot/kured)
- **Maintenance Window**: 04:00-08:00 UTC
- **Concurrency**: 1 node at a time
- **Reboot Check**: Every 15 minutes

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Node detects reboot required                              │
│    (Creates /var/run/reboot-required)                        │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. Kured daemon detects sentinel file                        │
│    (Checks every 15 minutes)                                 │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Checks if in maintenance window (04:00-08:00 UTC)         │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Acquires cluster reboot lock (ensures single node)        │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. Cordons node (prevents new pod scheduling)                │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 6. Drains node (evicts all pods gracefully)                  │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 7. Reboots node (waits 60 seconds, then reboots)            │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 8. Node comes back online, rejoins cluster                   │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│ 9. Kured uncordons node (allows pod scheduling)              │
└──────────────────────────────────────────────────────────────┘
```

## Installation

### Via Makefile (Recommended)

```bash
# Deploy Kured via ArgoCD
make kured-deploy

# Check status
make kured-status

# View logs
make kured-logs
```

### Via ArgoCD Directly

```bash
# Deploy the ArgoCD Application
kubectl apply -f kubernetes/applications/kured/application.yaml

# Monitor sync status
kubectl get application kured -n argocd
```

### Manual Helm Installation (Not Recommended)

If you need to install Kured without ArgoCD:

```bash
# Add Helm repository
helm repo add kubereboot https://kubereboot.github.io/charts
helm repo update

# Install Kured
helm upgrade --install kured kubereboot/kured \
  --namespace kube-system \
  --values kubernetes/services/kured/values.yaml \
  --wait
```

**Note**: The homelab uses GitOps with ArgoCD for application management. Manual Helm installation bypasses GitOps and is not recommended for production use.

## Configuration

### Maintenance Window

By default, Kured only reboots nodes during **04:00-08:00 UTC**. This prevents disruptions during business hours.

```yaml
# values.yaml
configuration:
  startTime: "04:00"  # UTC
  endTime: "08:00"    # UTC
  timezone: "UTC"
```

**Convert to your local time:**
- UTC 04:00-08:00 = PST/PDT 20:00-00:00 (8 PM - Midnight)
- UTC 04:00-08:00 = EST/EDT 23:00-03:00 (11 PM - 3 AM)
- UTC 04:00-08:00 = CET/CEST 05:00-09:00 (5 AM - 9 AM)

### Change Maintenance Window

Edit `values.yaml` and commit to Git. ArgoCD will automatically sync the changes:

```bash
# Edit maintenance window
vim kubernetes/services/kured/values.yaml

# Commit changes
git add kubernetes/services/kured/values.yaml
git commit -m "Update Kured maintenance window"
git push

# ArgoCD will automatically detect and apply changes
# Or manually sync:
kubectl -n argocd patch app kured --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Reboot Sentinel File

Kured monitors `/var/run/reboot-required` (Ubuntu/Debian standard). When this file exists, the node needs a reboot.

**How it gets created:**
- Automatic: `apt upgrade` creates it when kernel/critical packages are updated
- Manual: `touch /var/run/reboot-required` (for testing)

**Other distributions:**
```yaml
# For RHEL/CentOS/Fedora (use needs-restarting)
configuration:
  rebootSentinelCommand: "needs-restarting -r"
```

## Operational Tasks

### Check Kured Status

```bash
# View Kured DaemonSet
kubectl get daemonset -n kube-system kured

# View Kured pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=kured -f
```

### Force Immediate Reboot (Testing)

**WARNING**: Only use for testing!

```bash
# On a node, create reboot sentinel
ssh ubuntu@192.168.10.20 'sudo touch /var/run/reboot-required'

# Kured will detect on next check (within 15 minutes)
# If outside maintenance window, it will wait
```

### Disable Kured Temporarily

```bash
# Scale to 0 (no reboots)
kubectl scale daemonset -n kube-system kured --replicas=0

# Re-enable
kubectl scale daemonset -n kube-system kured --replicas=1
```

### Check Reboot Lock

```bash
# View lock annotation (which node holds the lock)
kubectl get ds -n kube-system kured -o jsonpath='{.metadata.annotations}'

# Check pending reboots across cluster
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.weave\.works/kured-node-lock}{"\n"}{end}'
```

## Monitoring

### Prometheus Metrics

Kured exposes Prometheus metrics on port 8080:

| Metric | Description |
|--------|-------------|
| `kured_reboot_required` | Whether a reboot is required (0/1) |
| `kured_reboot_time` | Time of last reboot |

**Enable ServiceMonitor** (when Prometheus is operational):

```yaml
# values.yaml
podMonitor:
  enabled: true
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
```

### Grafana Dashboard

Create a dashboard to track:
- Nodes requiring reboot
- Last reboot times
- Reboot history

**Example PromQL queries:**
```promql
# Nodes requiring reboot
sum(kured_reboot_required) by (node)

# Time since last reboot
time() - kured_reboot_time

# Total reboots in last 24h
increase(kured_reboot_time[24h])
```

## Notifications

### Slack Integration

Configure Slack notifications for reboot events:

```yaml
# values.yaml
configuration:
  slackHookUrl: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  slackChannel: "#ops-alerts"
  slackUsername: "Kured"
  messageTemplateDrain: "🔄 Node %s is being drained for reboot"
  messageTemplateReboot: "♻️  Node %s is rebooting now"
  messageTemplateUncordon: "✅ Node %s is back online"
```

**Using Sealed Secrets:**

```bash
# Create secret with webhook URL
kubectl create secret generic kured-slack \
  --from-literal=webhookUrl=https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -n kube-system \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > kubernetes/services/kured/slack-secret-sealed.yaml

# Reference in deployment
# (Requires custom Kured deployment modification)
```

## Troubleshooting

### Node Not Rebooting

1. **Check if reboot required:**
   ```bash
   ssh ubuntu@192.168.10.20 'ls -la /var/run/reboot-required'
   ```

2. **Check Kured logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=kured
   ```

3. **Common reasons:**
   - Outside maintenance window (04:00-08:00 UTC)
   - Another node holds the reboot lock
   - Node is cordoned manually
   - Kured DaemonSet not running

### Multiple Nodes Rebooting (Unexpected)

This should never happen! Kured ensures `concurrency: 1`.

**Check:**
```bash
# Verify concurrency setting
kubectl get daemonset -n kube-system kured -o jsonpath='{.spec.template.spec.containers[0].args}'

# Check for multiple Kured pods (should be one per node)
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured
```

### Reboot Stuck/Incomplete

1. **Check node status:**
   ```bash
   kubectl get nodes
   ```

2. **Check if node is cordoned:**
   ```bash
   kubectl get node <node-name> -o jsonpath='{.spec.unschedulable}'
   ```

3. **Manually uncordon if stuck:**
   ```bash
   kubectl uncordon <node-name>
   ```

4. **Check drain status:**
   ```bash
   kubectl get pods -A --field-selector spec.nodeName=<node-name>
   ```

### Node Offline After Reboot

1. **Check node in cluster:**
   ```bash
   kubectl get nodes
   ```

2. **SSH to node and check k3s:**
   ```bash
   ssh ubuntu@192.168.10.20 'sudo systemctl status k3s'
   ```

3. **Check Kured logs from before reboot:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=kured --previous
   ```

## Best Practices

### 1. Test in Non-Production First

```bash
# Force a test reboot on one node
ssh ubuntu@192.168.10.22 'sudo touch /var/run/reboot-required'

# Watch the process
kubectl logs -n kube-system -l app.kubernetes.io/name=kured -f
```

### 2. Set Appropriate Maintenance Windows

- Avoid peak hours
- Consider backup schedules
- Account for timezone differences

### 3. Monitor Reboot Activity

- Set up Prometheus alerts
- Track reboot frequency
- Monitor application health during reboots

### 4. Handle StatefulSets Carefully

Kured respects PodDisruptionBudgets. Ensure critical StatefulSets have PDbs:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: my-app
```

### 5. Backup Before Automated Reboots

Ensure Longhorn backups are scheduled before maintenance window:
- Backups: 03:00 UTC
- Reboots: 04:00-08:00 UTC

## Uninstallation

```bash
# Delete the ArgoCD Application
kubectl delete application kured -n argocd

# ArgoCD will automatically remove all Kured resources
# Verify removal
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured

# If you need to manually clean up (shouldn't be necessary):
helm uninstall kured -n kube-system
```

## Related Documentation

- [Kured GitHub](https://github.com/kubereboot/kured)
- [Kured Helm Chart](https://github.com/kubereboot/charts/tree/main/charts/kured)
- [Safe Node Maintenance](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [PodDisruptionBudgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)

## Configuration Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `configuration.concurrency` | `1` | Number of nodes to reboot simultaneously |
| `configuration.startTime` | `"04:00"` | Maintenance window start (UTC) |
| `configuration.endTime` | `"08:00"` | Maintenance window end (UTC) |
| `configuration.period` | `"15m"` | Check interval for reboot required |
| `configuration.rebootDelay` | `"60s"` | Delay before executing reboot |
| `configuration.rebootSentinel` | `/var/run/reboot-required` | File to monitor for reboot signal |
| `configuration.rebootCommand` | `/bin/systemctl reboot` | Command to execute reboot |
| `tolerations` | Control plane + master | Allow scheduling on all nodes |
| `priorityClassName` | `system-node-critical` | High priority scheduling |
