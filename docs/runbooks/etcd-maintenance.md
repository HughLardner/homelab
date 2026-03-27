# Etcd Maintenance & Health

**Purpose:** Routine maintenance and health checks for K3s embedded etcd to prevent database corruption and control-plane instability.

**Last updated:** 2026-03-27

---

## Overview

K3s uses an embedded etcd database for storing cluster state. The March 2026 incident revealed that repeated K3s crashes (64 restarts over 9 hours) can corrupt the etcd write-ahead log (WAL), leading to prolonged recovery times and potential data loss.

**Key metrics:**
- Database size: 38MB current / 2GB quota (monitoring alerts at 1.5GB / 75%)
- WAL fsync duration: p99 should be <1s
- Commit latency: p99 should be <0.5s
- Database open time: 9+ seconds during March 2026 (indicates fragmentation)

---

## Automated Maintenance

### Defragmentation CronJob

A CronJob runs every Sunday at 2am GMT to defragment the etcd database:

```bash
# Check CronJob status
kubectl -n monitoring get cronjob etcd-defrag

# View recent job runs
kubectl -n monitoring get jobs -l app.kubernetes.io/name=etcd-defrag --sort-by=.status.startTime

# Check logs from last run
kubectl -n monitoring logs job/etcd-defrag-<timestamp>
```

**What defragmentation does:**
- Reclaims space from deleted keys and compacted revisions
- Reduces database file size and improves read performance
- Prevents database from approaching the 2GB quota
- Reduces open time and fragmentation after repeated restarts

**Expected output:**
```
=== etcd defragmentation 2026-03-27T02:00:00Z ===
--- pre-defrag status ---
| ENDPOINT | DB SIZE | IN USE |
| 127.0.0.1:2379 | 38 MB | 25 MB |

--- running defragmentation ---
Finished defragmenting etcd member[127.0.0.1:2379]

--- post-defrag status ---
| ENDPOINT | DB SIZE | IN USE |
| 127.0.0.1:2379 | 26 MB | 25 MB |

--- defragmentation complete ---
```

---

## Manual Defragmentation

If the CronJob fails or you need to defragment outside the schedule:

### Option 1: Via kubectl exec (recommended)

```bash
# SSH to the node
ssh ubuntu@192.168.10.20

# Get etcd endpoint and certs
ETCD_ENDPOINT="https://127.0.0.1:2379"
CERT="/var/lib/rancher/k3s/server/tls/etcd/server-client.crt"
KEY="/var/lib/rancher/k3s/server/tls/etcd/server-client.key"
CA="/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt"

# Check status before defrag
sudo /usr/local/bin/k3s etcdctl \
  --endpoints=$ETCD_ENDPOINT \
  --cert=$CERT --key=$KEY --cacert=$CA \
  endpoint status -w table

# Run defragmentation
sudo /usr/local/bin/k3s etcdctl \
  --endpoints=$ETCD_ENDPOINT \
  --cert=$CERT --key=$KEY --cacert=$CA \
  defrag --command-timeout=60s

# Check status after defrag
sudo /usr/local/bin/k3s etcdctl \
  --endpoints=$ETCD_ENDPOINT \
  --cert=$CERT --key=$KEY --cacert=$CA \
  endpoint status -w table
```

### Option 2: Via CronJob manual trigger

```bash
# Create a one-off job from the CronJob
kubectl -n monitoring create job etcd-defrag-manual --from=cronjob/etcd-defrag

# Watch the job
kubectl -n monitoring get job etcd-defrag-manual -w

# Check logs
kubectl -n monitoring logs job/etcd-defrag-manual
```

---

## Health Checks

### 1. Database Size

Monitor database size to prevent approaching the 2GB quota:

```bash
# Via Prometheus metrics
kubectl -n monitoring port-forward svc/vmsingle 8429:8428
# Then query: etcd_mvcc_db_total_size_in_bytes

# Via etcdctl
ssh ubuntu@192.168.10.20
sudo /usr/local/bin/k3s etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  endpoint status -w table
```

**Alert thresholds:**
- Warning: >1.5GB (75% of quota) - `EtcdDatabaseSizeHigh`
- Action required: >1.8GB (90% of quota) - manual defragmentation needed

### 2. Leader Status

Check etcd leader election:

```bash
# Via Prometheus metrics
# Query: etcd_server_has_leader (should be 1)

# Via etcdctl
sudo /usr/local/bin/k3s etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  endpoint status -w table
```

**Alert:** `EtcdNoLeader` fires if leader is lost for >2 minutes (critical severity)

### 3. Commit Latency

High commit latency indicates disk I/O saturation or backend storage issues:

```bash
# Via Prometheus metrics
# Query: histogram_quantile(0.99, rate(etcd_disk_backend_commit_duration_seconds_bucket[5m]))
```

**Alert thresholds:**
- Warning: p99 >0.5s - `EtcdHighCommitLatency`
- Expected: p99 <0.2s during normal operations

### 4. WAL Fsync Duration

Slow WAL fsync indicates disk I/O saturation and increases corruption risk:

```bash
# Via Prometheus metrics
# Query: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))
```

**Alert thresholds:**
- Warning: p99 >1s - `EtcdSlowFsync`
- Expected: p99 <0.5s during normal operations

**Historical context:** The March 2026 incident showed etcd WAL corruption (`0000000000000240-0000000001d7face.wal.broken`) from 64 unclean K3s shutdowns.

---

## Monitoring Dashboard

The "Node Saturation & Control Plane Health" dashboard in Grafana includes 4 etcd panels:

1. **Etcd Database Size** - Time series showing database growth (alert threshold at 1.5GB)
2. **Etcd Leader Status** - Stat panel (green=has leader, red=no leader)
3. **Etcd Commit Latency (p99)** - Time series with warning/critical thresholds
4. **Etcd WAL Fsync Duration (p99)** - Time series with warning/critical thresholds

Access via: `https://grafana.silverseekers.org` → Dashboards → Node Saturation & Control Plane Health

---

## Recovery from Corruption

### Symptoms of etcd corruption:
- K3s repeatedly failing to start
- API server unavailable (HTTP 503 errors)
- Etcd logs showing WAL corruption or database errors
- Broken WAL files in `/var/lib/rancher/k3s/server/db/etcd/member/wal/`

### Recovery steps:

#### 1. Check for broken WAL files

```bash
ssh ubuntu@192.168.10.20
ls -lah /var/lib/rancher/k3s/server/db/etcd/member/wal/ | grep broken
```

If broken WAL files exist (e.g., `*.wal.broken`), etcd detected corruption and moved them aside.

#### 2. Restore from Velero backup

**Before attempting recovery:** Ensure you have a recent Velero backup:

```bash
# Check recent backups
kubectl -n velero get backups --sort-by=.status.startTimestamp

# Verify backup contains etcd data
kubectl -n velero describe backup <backup-name>
```

**Full cluster restore procedure:**
See `docs/VELERO_BACKUP_RESTORE.md` for complete instructions.

#### 3. K3s etcd snapshot (last resort)

If Velero backups are unavailable, K3s maintains automatic etcd snapshots:

```bash
# List available snapshots
ssh ubuntu@192.168.10.20
sudo ls -lah /var/lib/rancher/k3s/server/db/snapshots/

# Restore from snapshot (DESTRUCTIVE - all changes since snapshot are lost)
sudo systemctl stop k3s
sudo /usr/local/bin/k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>

# After successful restore, start K3s normally
sudo systemctl start k3s
```

**Warning:** Cluster reset is destructive. Only use if:
- Velero restore fails or backups are unavailable
- The cluster is completely non-functional
- You accept data loss since the snapshot time

---

## Increasing etcd Quota

If the database consistently approaches 1.5GB despite regular defragmentation:

### Option 1: K3s server argument (permanent)

Edit K3s service configuration:

```bash
ssh ubuntu@192.168.10.20
sudo vi /etc/systemd/system/k3s.service

# Add to ExecStart line:
--etcd-arg quota-backend-bytes=4294967296  # 4GB quota

sudo systemctl daemon-reload
sudo systemctl restart k3s
```

### Option 2: Via Ansible (recommended for consistency)

Update `ansible/roles/k3s/templates/k3s.service.j2` to include:
```
--etcd-arg quota-backend-bytes={{ k3s_etcd_quota_bytes | default('2147483648') }}
```

Set in your vars:
```yaml
k3s_etcd_quota_bytes: 4294967296  # 4GB
```

Then re-run: `make k3s-install`

**Note:** Increasing quota requires restart and may extend recovery time during future incidents. Only increase if growth is legitimate (e.g., many resources, frequent changes).

---

## When to Run Manual Defragmentation

- Database size >1.5GB (alert `EtcdDatabaseSizeHigh` will fire)
- After major cluster changes (many resource creates/deletes)
- Before and after Kubernetes version upgrades
- After recovering from K3s crash loops
- If commit latency or WAL fsync duration is consistently high

---

## References

- [Etcd maintenance guide](https://etcd.io/docs/v3.5/op-guide/maintenance/)
- [K3s etcd configuration](https://docs.k3s.io/cli/server#etcd)
- March 2026 incident analysis: 64 K3s restarts → etcd WAL corruption → 20+ minute recovery
- Grafana dashboard: Node Saturation & Control Plane Health
- Alert rules: `kubernetes/applications/monitoring/templates/alert-rules.yaml` (etcd-health group)
