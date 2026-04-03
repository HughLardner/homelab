# Node I/O Saturation & Recovery

**Last incident:** 2026-03-18 — VM 120 (homelab-node-0) became unresponsive; SSH and Kubernetes API timed out or refused connections.

---

## Root Cause Summary

The node entered a state of **severe I/O saturation**, which led to:

1. **High iowait** (86–91% of CPU time waiting on disk)
2. **systemd-journald stuck in D state** (uninterruptible wait on I/O), amplifying stalls
3. **iSCSI connection errors** (Longhorn: `conn error 1022`) under load
4. **K3s never finishing startup** — API server never bound to 6443 because etcd/control plane was blocked on the same saturated I/O
5. **VM hang** when attempting `systemctl restart k3s` (no CPU/IO headroom to complete the restart)

So the **primary cause was disk/I/O saturation**, not memory. Proxmox showing 100% memory is normal for this cluster’s balloon behaviour; guest usage was ~10 GiB with ~1 GiB available.

---

## Contributing Factors

| Factor | Detail |
|--------|--------|
| **Many workloads on one node** | Plex, Home Assistant, CouchDB, Gitea, Node-RED, Pi-hole, monitoring (VMAgent, VMSingle), Longhorn, Traefik, etc. on a single 12 GB / 4-core VM |
| **15 Longhorn (iSCSI) volumes** | All volumes go through a **single** Longhorn instance-manager (10.42.0.5). One process handling 15 volumes increases I/O contention and timeout risk |
| **Heavy log writers** | Many pods writing to stdout → journald → disk. No rate limiting was in place, so under load journald could block on I/O |
| **Heavy readers** | iotop showed `prometheus-config-reloader` at ~113 MB/s read, plus significant read from Traefik, Node-RED, cert-manager webhook, Home Assistant |
| **Single node** | No headroom; when the node is saturated, the control plane (K3s/etcd) runs on the same overloaded disk and can’t complete startup |

---

## What Was Done (Incident Response)

1. **Journald rate limiting** (persistent, on the node):
   - `/etc/systemd/journald.conf.d/ratelimit.conf`: `RateLimitBurst=2000`, `RateLimitIntervalSec=30s`
   - Reduces log I/O spikes and lowers the chance of journald blocking in D state
2. **Proxmox reboot** of VM 120 when the VM hung (safe for single-node; Longhorn reconnects after boot).
3. **No iSCSI logout/login** — sessions were LOGGED IN; reconnecting would have added churn.

---

## Prevention Measures

### 1. Keep journald rate limiting (already applied)

**Ansible (recommended):** The `node-prep` role now deploys this automatically. Run `make node-prep` or re-run your node preparation playbook so all current and future nodes get the config:

- `ansible/roles/node-prep/tasks/main.yml` — tasks "Deploy journald rate limit config" and "Restart journald after rate limit config change"
- Controlled by `node_prep_configure_journald_ratelimit` (default: `true`) in `roles/node-prep/defaults/main.yml`

**Manual (one-off):** On a node where Ansible hasn’t been run yet:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
echo -e '[Journal]\nRateLimitBurst=2000\nRateLimitIntervalSec=30s' | sudo tee /etc/systemd/journald.conf.d/ratelimit.conf
sudo systemctl restart systemd-journald
```

### 2. Reduce monitoring I/O where possible

- **VMAgent**: Already using `scrapeInterval: "60s"`. Avoid lowering it further; if you add many scrape targets, consider increasing interval or dropping non-essential targets.
- **Config-reloader**: The Victoria Metrics operator injects a config-reloader sidecar. If you see very high read I/O from it again, check operator/VMAgent CRD for options to increase reload interval or reduce config churn (e.g. fewer frequently-changing ConfigMaps).

### 3. Longhorn

- All 15 volumes through one instance-manager is a known bottleneck on a single node. Options:
  - Prefer **local-path** or **ephemeral** storage for non-critical data where possible to reduce Longhorn I/O.
  - Ensure Longhorn’s backing storage (`/mnt/longhorn-data`) is on a performant disk (e.g. not a slow NFS or heavily shared disk).
- If the node is slow again and the API is reachable, restarting the Longhorn instance-manager on that node can help:  
  `kubectl -n longhorn-system delete pod -l longhorn.io/node=homelab-node-0 --field-selector=status.phase=Running`

### 4. Early warning (alerting / dashboards)

- **Dashboard**: Use `Node and Storage Health` in Grafana for the node/storage view, and use Grafana Explore with `VictoriaMetrics` for etcd-specific queries from the etcd maintenance runbook:
  - node pressure (`iowait`, disk util, throughput, memory, rootfs free space/inodes)
  - control-plane health (API `up`, 5xx rate, p95/p99 latency)
  - storage health (Longhorn robustness counts, instance-manager memory)
  - cluster churn (restart spikes by namespace and by pod)
- **VMAlert rules** now watch the recurrence pattern directly:
  - `NodeHighIOWait`, `NodeCriticalIOWait`, `NodeDiskIOSaturated`, `NodeHighDiskReadRate`
  - `KubeAPIServerUnavailable`, `KubeAPIServerHigh5xxRate`, `KubeAPIServerP99LatencyHigh`
  - `LonghornVolumeFaulted`, `LonghornVolumeUnexpectedUnknown`
  - `ClusterPodRestartSpike`, `InfrastructurePodRestartSpike`
- These alerts provide early warning so you can scale down noisy workloads or investigate before the node becomes unreachable.

### 5. Preserve short-lived evidence

- A lightweight `instability-snapshot` CronJob in `monitoring` logs a periodic snapshot of:
  - node conditions
  - recent warning events
  - top restarting pods
  - Longhorn non-healthy volumes
- Those logs are scraped by Promtail and retained in Loki, so transient failures are still reviewable after the cluster recovers.

### 6. Rollout and threshold tuning

- **Initial validation after deploy**:
  - confirm the `Node and Storage Health` dashboard loads and shows data for the node and Longhorn panels
  - confirm VMAlert loads the new rules without evaluation errors
  - verify the `instability-snapshot` CronJob runs and logs appear in Loki
- **Burn-in review (first week)**:
  - review all firings of `KubeAPIServerHigh5xxRate`, `KubeAPIServerP99LatencyHigh`, `ClusterPodRestartSpike`, and `LonghornVolumeUnexpectedUnknown`
  - tighten thresholds if the alerts are too chatty during normal operation
  - relax thresholds only if they are clearly firing on known-safe, steady-state behaviour
- **Monthly review**:
  - compare alert firings to actual incidents or near-misses
  - adjust thresholds only with a short note explaining why the old threshold was wrong

### 7. Resource and workload balance

- **Resource requests/limits**: Ensure noisy workloads (Plex, Home Assistant, CouchDB, monitoring) have limits so one pod can’t monopolise CPU/IO.
- **Consider moving heaviest apps off the cluster**: Running Plex or Home Assistant on a separate host (or a dedicated VM) would reduce I/O and CPU contention on the single K3s node.

### 8. Graceful node reboots after kernel updates

**Status:** Kured is deployed and now tuned for single-node operation.

Current repo behavior:
- Detect when kernel updates require a reboot (via `/var/run/reboot-required`)
- Wait for the configured maintenance window (`03:00-05:00` in `Europe/Dublin`)
- Cordon the node to prevent new pod scheduling
- Drain pods from the node before rebooting, but only for a bounded period
- Reboot the node
- Uncordon the node after it comes back online
- Coordinate reboots across the cluster (concurrency: 1 node at a time)

Single-node safeguards now expected during planned reboots:
- Traefik and Sealed Secrets do not publish blocking PodDisruptionBudgets
- Longhorn uses an `always-allow` node drain policy when the cluster has one node
- Kured uses a `10m` drain timeout and `60s` skip-wait-for-delete timeout so the node cannot remain cordoned indefinitely

Operational expectation:
- a reboot is a short planned full-cluster outage, not a zero-downtime failover event
- all non-DaemonSet pods will restart after the node returns
- if the node is still `SchedulingDisabled` after the maintenance window, treat it as a failed reboot recovery and run the checks below

**Configuration location:** `kubernetes/services/kured/`
- `values.yaml` - Kured configuration (maintenance window, concurrency, etc.)
- `application.yaml` - ArgoCD Application manifest (sync wave 4)
- `README.md` - Comprehensive documentation and troubleshooting guide

**Post-reboot verification:**
```bash
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get applications.argoproj.io -A
kubectl get events -A --sort-by=.lastTimestamp | rg "FailedScheduling|unschedulable|Drain|Evict" -i
```

### 9. If you increase capacity

- **More RAM** for the VM (e.g. 16 GB) gives more buffer for cache and reduces pressure that can indirectly increase I/O.
- **Second node** would spread workloads and Longhorn traffic and avoid control-plane and data plane sharing one saturated machine.

---

## Runbook: Node Slow or Unresponsive Again

1. **From Proxmox**  
   - Check VM 120 status: `qm status 120`  
   - If the VM is responsive: use **qm guest exec** to run `cat /proc/loadavg` and `vmstat 1 3`. High `wa` (iowait) and high load → I/O saturation again.

2. **If you can SSH in**
   - Run: `vmstat 1 5`, `ps aux \| awk '$8 ~ /D/ { print }'`, `sudo dmesg \| tail -30 \| grep -iE 'oom|error|i/o|connection'`
   - If journald is in D state and iowait is high: journald rate limit should already be in place; consider temporarily scaling down vmagent:
     `kubectl -n monitoring scale deployment vmagent-vmagent --replicas=0`
   - Restart journald only if the shell is responsive: `sudo systemctl restart systemd-journald`
   - Capture the first 10 minutes of evidence:
    - Grafana dashboard: `Node and Storage Health`
     - recent warnings: `kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 80`
     - Longhorn state: `kubectl -n longhorn-system get volumes.longhorn.io -o wide`
     - restart spike: `kubectl get pods -A -o "custom-columns=NS:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount" --no-headers | sort -k3 -nr | head -n 30`
     - **etcd health:** Check database size and WAL health (see [Etcd Maintenance Runbook](etcd-maintenance.md) for detailed checks)
       ```bash
       sudo /usr/local/bin/k3s etcdctl \
         --endpoints=https://127.0.0.1:2379 \
         --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
         --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
         --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
         endpoint status -w table
       ```

3. **If you cannot SSH and the API is unreachable**  
   - From Proxmox: try **Reboot** on the VM. If it doesn’t respond, use **Stop** then **Start**.  
   - After boot, wait 2–3 minutes, then try `kubectl get nodes` and SSH again.

4. **After recovery**  
   - Check Longhorn: `kubectl -n longhorn-system get nodes,pods -o wide`  
   - Restore vmagent if scaled down: `kubectl -n monitoring scale deployment vmagent-vmagent --replicas=1`  
   - Review the incident window in Grafana and Loki:
    - dashboard: `Node and Storage Health`
     - snapshot logs: `kubectl -n monitoring logs job/<instability-snapshot-job-name>`
   - Correlate:
     - node pressure rising first
     - API 5xx/latency deterioration next
     - Longhorn robustness changes or faulted volumes
     - restart spikes and probe failures last

---

## References

- Node diagnostics and iotop output (2026-03-18) — 15 Longhorn iSCSI sessions, one portal; prometheus-config-reloader and others as top readers.
- Journald rate limiting: [systemd.journal-fields(7)](https://www.freedesktop.org/software/systemd/man/journald.conf.html#RateLimitIntervalSec=).
- Longhorn: single instance-manager per node; I/O goes through that process.
