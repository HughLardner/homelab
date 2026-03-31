# Longhorn Instance-Manager Memory Leak Runbook

**Alert:** `LonghornInstanceManagerMemoryElevated` / `LonghornInstanceManagerMemoryCritical` / `LonghornInstanceManagerMemoryLeakGrowth`
**Severity:** Warning → Critical
**Component:** Longhorn Storage (instance-manager)

---

## Overview

Longhorn instance-manager pods manage engine instances for attached volumes. A memory leak was identified in March 2026 where instance-managers grow from 200MB to 3.4GB over 19 hours (~180MB/hour leak rate). This causes OOM kills and cluster instability.

**Mitigation:** Memory limits (1.5GB) and automated restart CronJob implemented to contain leak impact.

---

## Triage Steps

### 1. Check Current Memory Usage

```bash
# Get current instance-manager memory usage
kubectl top pods -n longhorn-system -l longhorn.io/component=instance-manager

# Expected output:
# NAME                                    CPU(cores)   MEMORY(bytes)
# instance-manager-e-xxxxx               10m          245Mi
# instance-manager-r-xxxxx               5m           189Mi
```

**Normal:** 200-300 MB per instance-manager
**Elevated:** 800 MB - 1.4 GB (alert threshold)
**Critical:** >1.4 GB (approaching OOM kill at 1.5 GB)

### 2. Check Memory Growth Trend

Access Grafana dashboard:
```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Navigate to: http://localhost:3000
# Dashboard: "Longhorn" or "Node Saturation & Control Plane"
# Metric: longhorn_instance_manager_memory_usage_bytes
```

Expected: <10 MB/hour (stable)
Leak pattern: >100 MB/hour

### 3. Check Instance-Manager Uptime

```bash
# Check pod creation time
kubectl get pods -n longhorn-system -l longhorn.io/component=instance-manager \
  -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp

# Leak correlation: Longer uptime = higher memory usage
# If uptime >10 hours and memory >1GB → leak confirmed
```

### 4. Check for OOM Events

```bash
# Check if OOM kills have occurred
kubectl get events -n longhorn-system \
  --field-selector reason=OOMKilled \
  --sort-by=.lastTimestamp | tail -10
```

---

## Resolution

### Automated Resolution (Preferred)

A CronJob runs every 6 hours to automatically restart instance-managers with >1GB memory usage:

```bash
# Check CronJob status
kubectl get cronjob -n monitoring longhorn-instance-manager-restart

# Check last run
kubectl get jobs -n monitoring -l app.kubernetes.io/name=longhorn-instance-manager-restart \
  --sort-by=.status.startTime | tail -1

# View logs from last run
LAST_JOB=$(kubectl get jobs -n monitoring -l app.kubernetes.io/name=longhorn-instance-manager-restart \
  --sort-by=.status.startTime -o jsonpath='{.items[-1].metadata.name}')
kubectl logs -n monitoring job/$LAST_JOB
```

If the automated restart hasn't triggered yet or failed:

### Manual Restart (If Automated Job Failed)

```bash
# Restart specific instance-manager
kubectl delete pod -n longhorn-system <instance-manager-pod-name>

# Restart ALL instance-managers (more disruptive)
kubectl delete pods -n longhorn-system -l longhorn.io/component=instance-manager

# Longhorn automatically recreates deleted instance-managers
# Expect 30-60 seconds of volume unavailability during restart
```

**Impact:**
- Volumes using the restarted instance-manager become temporarily unavailable (30-60s)
- Pods using those volumes will see I/O errors during detach/reattach
- Longhorn automatically reattaches volumes after pod recreation

### Emergency: Increase Memory Limit (If OOM Loop)

If instance-managers are OOM looping (crash immediately after creation):

```bash
# Increase memory limit from 1.5GB to 3GB temporarily
kubectl patch settings.longhorn.io -n longhorn-system guaranteed-instance-manager-memory \
  --type=merge -p '{"value":"3072"}'

# Restart instance-managers to apply new limit
kubectl delete pods -n longhorn-system -l longhorn.io/component=instance-manager

# File incident for upstream Longhorn bug report
# Revert limit increase after leak is resolved upstream
```

---

## Root Cause Investigation

### Collect Diagnostic Data

```bash
# Get instance-manager logs
kubectl logs -n longhorn-system <instance-manager-pod> --tail=500 > im-logs.txt

# Get volume attachment status
kubectl get volumes.longhorn.io -n longhorn-system -o yaml > volumes.yaml

# Check Longhorn settings
kubectl get settings.longhorn.io -n longhorn-system -o yaml > longhorn-settings.yaml
```

### Common Causes

1. **Upstream Bug:**
   - Known issue in Longhorn v1.11.0 and earlier
   - Check: https://github.com/longhorn/longhorn/issues
   - Workaround: Automated restarts (Phase 3 implementation)

2. **Volume Churn:**
   - Rapid volume attach/detach can leak memory
   - Check for pods with frequent restart loops
   - Fix: Stabilize pods before addressing instance-manager leak

3. **Snapshot Operations:**
   - Snapshot creation/deletion can leak memory
   - Check for excessive snapshot counts
   - Fix: Reduce snapshot frequency or enable auto-cleanup

---

## Prevention

1. **Monitor Alerts:** Subscribe to `LonghornInstanceManagerMemory*` alerts
2. **Automated Restart:** Ensure CronJob is enabled and healthy
3. **Memory Limits:** Keep 1.5GB limit enforced (prevents cluster-wide impact)
4. **Upgrade Longhorn:** Check for bug fixes in newer releases
5. **Weekly Review:** Check instance-manager uptime vs memory usage trend

---

## Escalation

If automated + manual restarts don't resolve the issue:

1. **Check Longhorn version for known bugs:**
   ```bash
   helm list -n longhorn-system
   # Check https://github.com/longhorn/longhorn/releases for fixes
   ```

2. **Consider Longhorn upgrade:**
   ```bash
   # Test in staging first
   make longhorn-upgrade VERSION=v1.12.0
   ```

3. **File upstream bug report:**
   - Repository: https://github.com/longhorn/longhorn/issues
   - Include: Memory growth graphs, logs, volume count, cluster size
   - Reference: March 2026 incident (K3s 3,295 restarts in 7 days)

---

## References

- Implementation Plan: `/Users/hlardner/.claude/plans/elegant-munching-dusk.md`
- Longhorn Settings: `/kubernetes/services/longhorn/templates/settings.yaml`
- Automated Restart CronJob: `/kubernetes/applications/monitoring/templates/longhorn-instance-manager-restart-cronjob.yaml`
- Alert Rules: `/kubernetes/applications/monitoring/templates/alert-rules.yaml`
