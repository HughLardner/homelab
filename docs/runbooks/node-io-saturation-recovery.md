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

- **Grafana**: Add alerts (e.g. VMAlert or Grafana alerts) on:
  - **Node iowait** (e.g. `rate(node_cpu_seconds_total{mode="iowait"}[5m])` high for >5–10 min)
  - **Node load** (e.g. load average > 2× number of cores for sustained period)
- So you can scale down heavy workloads or investigate before the node becomes unreachable.

### 5. Resource and workload balance

- **Resource requests/limits**: Ensure noisy workloads (Plex, Home Assistant, CouchDB, monitoring) have limits so one pod can’t monopolise CPU/IO.
- **Consider moving heaviest apps off the cluster**: Running Plex or Home Assistant on a separate host (or a dedicated VM) would reduce I/O and CPU contention on the single K3s node.

### 6. If you increase capacity

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

3. **If you cannot SSH and the API is unreachable**  
   - From Proxmox: try **Reboot** on the VM. If it doesn’t respond, use **Stop** then **Start**.  
   - After boot, wait 2–3 minutes, then try `kubectl get nodes` and SSH again.

4. **After recovery**  
   - Check Longhorn: `kubectl -n longhorn-system get nodes,pods -o wide`  
   - Restore vmagent if scaled down: `kubectl -n monitoring scale deployment vmagent-vmagent --replicas=1`  
   - Review Grafana for iowait/load over the incident window and add alerts if not already present.

---

## References

- Node diagnostics and iotop output (2026-03-18) — 15 Longhorn iSCSI sessions, one portal; prometheus-config-reloader and others as top readers.
- Journald rate limiting: [systemd.journal-fields(7)](https://www.freedesktop.org/software/systemd/man/journald.conf.html#RateLimitIntervalSec=).
- Longhorn: single instance-manager per node; I/O goes through that process.
