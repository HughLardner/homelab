# Resource Governance

**Purpose:** Enforce resource limits and scheduling priorities across the homelab Kubernetes cluster to prevent resource exhaustion and ensure critical services remain available during resource contention.

**Last updated:** 2026-03-27

---

## Overview

This single-node cluster (12GB RAM, 4 CPUs) requires careful resource management to prevent:
- Memory exhaustion causing OOM kills and kernel panic
- CPU saturation causing control-plane instability
- Storage exhaustion causing pod scheduling failures
- Priority inversion (low-priority workloads starving critical services)

**Governance mechanisms:**
1. **ResourceQuotas** - Namespace-level resource limits
2. **LimitRanges** - Default and maximum resource limits per pod/container
3. **PriorityClasses** - Pod scheduling priorities during resource contention

---

## ResourceQuotas

ResourceQuotas set hard limits on resource consumption per namespace, preventing any single namespace from consuming all cluster resources.

### Current Quotas

| Namespace | CPU Request | CPU Limit | Memory Request | Memory Limit | PVCs | Pods |
|-----------|-------------|-----------|----------------|--------------|------|------|
| **default** | 2 | 4 | 4Gi | 8Gi | 10 | 20 |
| **monitoring** | 4 | 8 | 8Gi | 16Gi | 10 | 30 |
| **loki** | 2 | 4 | 4Gi | 8Gi | 5 | 10 |
| **home-automation** | 2 | 4 | 4Gi | 8Gi | 10 | 20 |
| **home-assistant** | 2 | 2 | 3Gi | 4Gi | 5 | 10 |
| **obsidian-livesync** | 500m | 1 | 512Mi | 1Gi | 3 | 5 |
| **media** | 500m | 4 | 1.5Gi | 6Gi | 5 | 10 |

**Location:** `kubernetes/services/resource-policies/templates/resourcequota.yaml`

**Deployment status (2026-03-27):**
```bash
$ kubectl get resourcequota -A
NAMESPACE           NAME              AGE
default             namespace-quota   97d
home-assistant      namespace-quota   6h
home-automation     namespace-quota   6h
loki                namespace-quota   97d
media               namespace-quota   6h
monitoring          namespace-quota   97d
obsidian-livesync   namespace-quota   6h
```

### Quota Sizing Rationale

**Monitoring namespace (largest):**
- Victoria Metrics stack (vmsingle, vmagent, vmalert, alertmanager)
- Grafana
- Promtail
- Heavy metric scraping and log aggregation workload
- Allocated 50% of cluster resources (4/8 CPU, 8/16Gi memory)

**Home-automation namespace:**
- Node-RED (IoT automation, CPU-intensive flows)
- Zigbee2MQTT (real-time message processing)
- Mosquitto MQTT broker
- Requires low latency for home automation responses

**Home-assistant namespace:**
- Home Assistant core
- Home Assistant Matter Hub
- Real-time automation engine
- Limit matches request to prevent over-allocation

**Media namespace (Plex):**
- Low request (500m CPU / 1.5Gi memory) for idle state
- High limit (4 CPU / 6Gi memory) for GPU transcoding bursts
- Allows Plex to burst during active transcoding without starving other services

**Obsidian-livesync namespace (smallest):**
- Single CouchDB instance for note syncing
- Low request/limit due to infrequent sync activity

### Checking Quota Usage

```bash
# View all quotas
kubectl get resourcequota -A

# Detailed usage for a namespace
kubectl describe resourcequota -n home-automation

# Example output:
# Name:            namespace-quota
# Namespace:       home-automation
# Resource         Used   Hard
# --------         ----   ----
# limits.cpu       1100m  4
# limits.memory    1088Mi 8Gi
# persistentvolumeclaims 3 10
# pods             3      20
# requests.cpu     110m   2
# requests.memory  288Mi  4Gi
```

### Requesting Quota Increases

If you encounter `exceeded quota` errors:

1. **Check current usage:**
   ```bash
   kubectl describe resourcequota -n <namespace>
   ```

2. **Verify pod requests/limits:**
   ```bash
   kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'
   ```

3. **Determine if increase is justified:**
   - Is the namespace using >80% of current quota consistently?
   - Is the workload critical and cannot be optimized?
   - Would the increase leave sufficient headroom for other namespaces?

4. **Submit request:**
   - Edit `kubernetes/services/resource-policies/templates/resourcequota.yaml`
   - Increase the appropriate `hard` limits
   - Document the reason in the git commit message
   - Deploy via ArgoCD or `kubectl apply -f`

**Important:** Total allocated resources across all quotas should not exceed:
- **CPU requests:** ~10 cores (allows 2.5x overcommit on 4 cores)
- **CPU limits:** ~20 cores (allows 5x overcommit)
- **Memory requests:** ~24Gi (allows 2x overcommit on 12GB)
- **Memory limits:** ~40Gi (allows 3.3x overcommit)

These overcommit ratios account for:
- Pods rarely using their full request simultaneously
- Limits only enforced during actual contention
- Kernel caching and buffer/cache memory being reclaimable

---

## PriorityClasses

PriorityClasses determine which pods are scheduled first and which are evicted first during resource pressure.

### Available Priority Classes

| Priority Class | Value | Usage | Preemption |
|---------------|-------|-------|------------|
| **system-node-critical** | 2000001000 | Core Kubernetes components (kubelet, kube-proxy) | Yes |
| **system-cluster-critical** | 2000000000 | Cluster-critical addons (CoreDNS, MetalLB) | Yes |
| **homelab-critical** | 1000000 | Critical infrastructure (ArgoCD, cert-manager, sealed-secrets) | No |
| **homelab-standard** | 100000 | Standard workloads (Home Assistant, monitoring, ingress) | No |
| **homelab-interactive** | 10000 | Interactive services (dashboards, management UIs) | No |
| **homelab-batch** | 1000 | Batch jobs (backups, maintenance CronJobs) | No |

**Location:** `kubernetes/services/resource-policies/templates/priorityclass.yaml`

### Priority Class Assignments

**Current assignments (2026-03-27):**

| Application | Priority Class | Rationale |
|------------|----------------|-----------|
| **ArgoCD** | homelab-critical | GitOps controller, needed for cluster recovery |
| **Cert-manager** | homelab-critical | TLS certificate management, prevents service outages |
| **Sealed-secrets** | homelab-critical | Secret decryption, required for many services |
| **Traefik** | homelab-standard | Ingress controller, high priority but not recovery-critical |
| **Victoria Metrics** | homelab-standard | Monitoring stack, important but cluster can run without it |
| **Grafana** | homelab-standard | Monitoring UI |
| **Home Assistant** | homelab-standard | Home automation core |
| **Home Assistant Matter Hub** | homelab-standard | Matter bridge |
| **Homepage** | homelab-interactive | Dashboard UI |
| **Headlamp** | homelab-interactive | Kubernetes UI |
| **Quartz** | homelab-interactive | Digital garden static site |
| **Velero** | homelab-batch | Backup jobs |
| **Etcd-defrag** | homelab-batch | Maintenance CronJob |

### Priority Class Behavior During Resource Pressure

When the cluster runs out of resources to schedule new pods:

1. **Scheduler prioritizes by priority class value:**
   - Higher priority pods are scheduled first
   - Lower priority pods wait in Pending state

2. **Kubelet evicts pods to free resources:**
   - Lowest priority pods are evicted first
   - Pods with `priorityClassName: homelab-batch` evicted before `homelab-interactive`
   - Pods with `priorityClassName: homelab-interactive` evicted before `homelab-standard`
   - System pods (`system-cluster-critical`, `system-node-critical`) are never evicted

3. **Preemption (for critical classes):**
   - `system-node-critical` and `system-cluster-critical` can preempt any lower priority pod
   - `homelab-*` classes do NOT preempt (safer for single-node cluster)

### Assigning Priority Classes

**For new applications:**

1. **Determine criticality:**
   - Critical: Required for cluster recovery or certificate management
   - Standard: Important services users depend on
   - Interactive: Management UIs, nice to have but not essential
   - Batch: Background jobs, can be restarted without impact

2. **Add to Helm values:**
   ```yaml
   priorityClassName: homelab-standard
   ```

3. **For local Helm charts:**
   - Add to `values.yaml` (default value)
   - Reference in `deployment.yaml`: `priorityClassName: {{ .Values.priorityClassName }}`

4. **For external Helm charts:**
   - Add to `*-values.yaml` file (e.g., `traefik-values.yaml`)
   - Pass through ArgoCD Application or Ansible helm install

**Example:**
```yaml
# kubernetes/applications/homepage/homepage-values.yaml
priorityClassName: homelab-interactive

resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Verifying Priority Classes

```bash
# Check priority classes on pods
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
PRIORITY:.spec.priorityClassName,\
PRIORITY_VALUE:.spec.priority

# Check which pods would be evicted first
kubectl get pods -A --sort-by=.spec.priority
```

---

## LimitRanges

LimitRanges provide default and maximum resource limits for containers and pods that don't specify them explicitly.

### Current LimitRanges

**Default namespace:**
```yaml
# Container defaults
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 500m
  memory: 512Mi

# Container maximums
max:
  cpu: 2
  memory: 4Gi
```

**Monitoring namespace:**
```yaml
# Container defaults
requests:
  cpu: 100m
  memory: 128Mi
limits:
  cpu: 1
  memory: 1Gi

# Container maximums
max:
  cpu: 4
  memory: 8Gi
```

**Location:** `kubernetes/services/resource-policies/templates/limitrange.yaml`

### LimitRange Purpose

1. **Prevent unbounded pods:**
   - Pods without resource requests/limits get reasonable defaults
   - Prevents OOM kill surprises and resource starvation

2. **Enforce maximums:**
   - Prevents a single container from requesting all cluster resources
   - Caught at pod creation time (before scheduling)

3. **Resource planning:**
   - Makes capacity planning predictable
   - Enables meaningful ResourceQuota enforcement

### Common LimitRange Errors

**Error:** `Error creating: pods "my-pod" is forbidden: maximum cpu usage per Container is 2, but limit is 4`

**Solution:** The container requests more CPU than the LimitRange maximum. Either:
- Reduce the container's CPU limit
- Increase the LimitRange maximum (with justification)
- Move the workload to a namespace with higher limits

---

## Resource Requests vs Limits

Understanding the difference is critical for effective resource governance:

### Requests (Guaranteed Resources)

- Used by scheduler to decide pod placement
- Guaranteed to be available to the pod
- Sum of requests across all pods determines schedulability
- Over-committing requests is safe if pods don't all use full request simultaneously

**Example:**
```yaml
resources:
  requests:
    cpu: 100m      # Scheduler reserves 0.1 CPU core
    memory: 128Mi  # Scheduler reserves 128Mi RAM
```

### Limits (Maximum Resources)

- Maximum resources the container can consume
- Enforced by kubelet via cgroups
- Exceeding memory limit → OOMKilled
- Exceeding CPU limit → throttled (not killed)
- Over-committing limits is common and safe

**Example:**
```yaml
resources:
  limits:
    cpu: 500m      # Throttled if using >0.5 CPU cores
    memory: 512Mi  # OOMKilled if using >512Mi RAM
```

### Best Practices

1. **Always set requests:**
   - Enables proper scheduling
   - Prevents pending pods due to insufficient resources

2. **Set limits for memory-intensive workloads:**
   - Prevents one pod from consuming all memory
   - Especially important for Java, Node.js, database workloads

3. **Requests should match typical usage:**
   - Not worst-case or peak usage
   - Based on actual metrics (Grafana, `kubectl top`)

4. **Limits should be 2-5x requests:**
   - Allows bursting during peak load
   - Prevents excessive over-commit

**Example (well-tuned):**
```yaml
# Node-RED (typical: 80m CPU, 200Mi memory; peak: 300m CPU, 400Mi memory)
resources:
  requests:
    cpu: 100m      # Slightly above typical
    memory: 256Mi  # Room for growth
  limits:
    cpu: 500m      # 5x request, allows bursting
    memory: 512Mi  # 2x request, prevents runaway memory leak
```

---

## Monitoring Resource Usage

### Via Grafana

**Dashboard:** "Kubernetes Cluster Homelab"
- Panels show CPU and memory usage by namespace and pod
- Compare actual usage vs requests/limits

**Dashboard:** "ResourceQuota"
- Shows quota usage percentage per namespace
- Alerts when approaching quota limits

### Via kubectl

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage (all namespaces)
kubectl top pods -A --sort-by=memory

# Pod resource usage (specific namespace)
kubectl top pods -n monitoring --sort-by=cpu

# Compare usage to requests/limits
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
CPU_LIMIT:.spec.containers[*].resources.limits.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory,\
MEM_LIMIT:.spec.containers[*].resources.limits.memory
```

### Via Victoria Metrics

**Useful queries:**
```promql
# CPU usage by namespace
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)

# Memory usage by namespace
sum(container_memory_working_set_bytes) by (namespace)

# CPU request utilization (%)
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace) /
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace) * 100

# Memory request utilization (%)
sum(container_memory_working_set_bytes) by (namespace) /
sum(kube_pod_container_resource_requests{resource="memory"}) by (namespace) * 100
```

---

## Troubleshooting

### Pods Stuck in Pending

**Check events:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
1. **Insufficient CPU/memory:**
   - Message: `Insufficient cpu` or `Insufficient memory`
   - Solution: Reduce pod requests or add cluster capacity

2. **ResourceQuota exceeded:**
   - Message: `exceeded quota: namespace-quota`
   - Solution: Check quota usage (`kubectl describe resourcequota -n <namespace>`)
   - Either reduce existing pod resources or request quota increase

3. **No nodes match affinity:**
   - Message: `0/1 nodes are available: 1 node(s) didn't match pod affinity/anti-affinity`
   - Solution: Check pod affinity rules, may need to relax constraints

### Pods OOMKilled

**Check pod status:**
```bash
kubectl get pods -n <namespace>
# Look for STATUS: OOMKilled or CrashLoopBackOff with reason OOMKilled
```

**Check events:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Container was OOMKilled"
```

**Solutions:**
1. Increase memory limit (if workload genuinely needs more)
2. Fix memory leak (if usage grows unbounded)
3. Add swap to node (emergency only, degrades performance)

### Pods Evicted

**Check events:**
```bash
kubectl get events -A --field-selector reason=Evicted --sort-by=.lastTimestamp
```

**Common causes:**
1. **Node memory pressure:**
   - Kubelet evicts lowest priority pods to prevent OOM
   - Solution: Reduce memory usage or add capacity

2. **Node disk pressure:**
   - Kubelet evicts pods when disk usage >85%
   - Solution: Clean up old images, logs, or add disk space

**Check eviction thresholds:**
```bash
kubectl describe node homelab-node-0 | grep -A 10 "Allocatable:"
```

---

## References

- Kubernetes ResourceQuotas: https://kubernetes.io/docs/concepts/policy/resource-quotas/
- LimitRanges: https://kubernetes.io/docs/concepts/policy/limit-range/
- PriorityClasses: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/
- Node-pressure eviction: https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/
- March 2026 incident: Resource quotas and priority classes implemented to prevent future resource exhaustion
- Files:
  - `kubernetes/services/resource-policies/templates/resourcequota.yaml`
  - `kubernetes/services/resource-policies/templates/limitrange.yaml`
  - `kubernetes/services/resource-policies/templates/priorityclass.yaml`
