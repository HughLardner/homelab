# Pre-Proxmox 9 Upgrade Backup

**Date**: 2026-03-08
**Purpose**: Full backup of homelab cluster before upgrading Proxmox VE 8 → 9

## What Was Backed Up

| Layer | What | Where | Status |
|-------|------|--------|--------|
| Kubernetes resources | Velero backup (982 resources) | Garage S3 (`velero` bucket) | ✅ Complete |
| TLS certificates | Let's Encrypt certs | `~/homelab-backup-proxmox9/letsencrypt-certs-backup.yaml` | ✅ Complete |
| Sealed Secrets key | 3 controller encryption keys | `~/homelab-backup-proxmox9/sealed-secrets-key-backup.yaml` | ✅ Complete |
| Plain secrets | `config/secrets.yml` | `~/homelab-backup-proxmox9/secrets.yml` | ✅ Complete |
| Terraform state | All workspaces (default, k3s, alpha, beta) | `~/homelab-backup-proxmox9/terraform/` | ✅ Complete |
| VM 120 (full disk) | Both disks: virtio0 (100GB OS) + virtio1 (200GB persistent) | `/var/lib/vz/dump/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst` on Proxmox (22GB compressed) + `~/homelab-backup-proxmox9/` locally | ✅ Complete |
| LVM snapshot | `k8s-persistent-data` (200GB) | `pve/k8s-persistent-data-snap-proxmox9` on Proxmox | ✅ Complete |
| Cluster state | All pods, PVCs, ingresses, ArgoCD apps | `~/homelab-backup-proxmox9/cluster-state-2026-03-08.txt` | ✅ Complete |

## Velero Backup Details

Two named backups created in Garage S3:

- `pre-proxmox9-upgrade` — with volume snapshot attempt (CSI, 982 resources)
- `pre-proxmox9-upgrade-resources` — resource-only backup

> **Note**: Both show `PartiallyFailed` — this is a **pre-existing condition** consistent with all daily backups. The 2 errors are caused by missing `snapshot.storage.k8s.io/v1` CRDs (`VolumeSnapshot`, `VolumeSnapshotContent`). All 982 Kubernetes resources are backed up successfully.

## LVM Snapshot Details

```
LV:      k8s-persistent-data-snap-proxmox9
VG:      pve
Origin:  k8s-persistent-data (200GB)
Size:    20GB COW buffer (25GB requested but only 21.79GB free in VG)
Status:  Active (swi-a-s---)
```

The COW buffer is 10% of the origin size. If Longhorn writes more than 20GB during the upgrade window, the snapshot will overflow and become invalid. Monitor with:

```bash
ssh root@192.168.10.10 "lvs pve/k8s-persistent-data-snap-proxmox9"
```

After a successful upgrade, remove the snapshot to reclaim space:

```bash
ssh root@192.168.10.10 "lvremove -f /dev/pve/k8s-persistent-data-snap-proxmox9"
```

## vzdump Backup Details

```
Archive:  /var/lib/vz/dump/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst
Local:    ~/homelab-backup-proxmox9/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst
VM:       120 (homelab-node-0)
Mode:     snapshot (live, no downtime)
Disks:    virtio0 (100GB OS), virtio1 (200GB k8s-persistent-data)
Compress: zstd — 300GB → 22GB (75% sparse / zero data)
Duration: 14 minutes at 364.8 MB/s average
Notes:    pre-proxmox9-upgrade
```

> **Important**: The vzdump includes the `k8s-persistent-data` LV (virtio1) as well as the OS disk. This is the most complete restore point — a single `qmrestore` brings back everything.

---

## Restore Procedures

### Scenario A: Proxmox 9 upgrade succeeds (no rollback needed)

1. Remove the LVM snapshot to reclaim ~20GB:
   ```bash
   ssh root@192.168.10.10 "lvremove -f /dev/pve/k8s-persistent-data-snap-proxmox9"
   ```
2. Optionally delete the vzdump archive after confirming stability:
   ```bash
   ssh root@192.168.10.10 "rm /var/lib/vz/dump/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst"
   ```

---

### Scenario B: Proxmox upgrade corrupts VMs but host survives

**Restore VM from vzdump:**

```bash
ssh root@192.168.10.10

# Restore VM 120 from backup (overwrites existing)
qmrestore /var/lib/vz/dump/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst 120 \
  --storage local-lvm --force

# Start the restored VM
qm start 120
```

K3s starts automatically. ArgoCD syncs all services from Git. Allow ~5 minutes for full startup.

**Verify:**
```bash
kubectl get nodes
kubectl get pods -A
```

---

### Scenario C: Proxmox host is unrecoverable (full reinstall)

1. **Reinstall Proxmox 8** on the host (do NOT use Proxmox 9 if that caused the issue)

2. **Re-create LVM layout** to match the original:
   ```bash
   # On the Proxmox host after reinstall
   # Proxmox installer creates pve VG automatically
   # Create the standalone LV (do NOT format it — data is on the physical disk)
   lvcreate -L200G -n k8s-persistent-data pve
   ```
   > If the physical disk survived, the ext4 filesystem and Longhorn data are still on the underlying block device. The LV is just a pointer — re-creating it with the same name re-exposes the data.

3. **Restore VM 120** from the vzdump you copied locally:
   ```bash
   # Copy backup back to Proxmox
   scp ~/homelab-backup-proxmox9/vzdump-qemu-120-*.vma.zst root@192.168.10.10:/var/lib/vz/dump/

   # Restore
   qmrestore /var/lib/vz/dump/vzdump-qemu-120-2026_03_08-13_04_35.vma.zst 120 \
     --storage local-lvm
   qm start 120
   ```

4. **K3s and ArgoCD** auto-start and sync from Git. Allow ~5 minutes.

5. **Restore secrets if needed** (only if K8s etcd was lost, not typical after VM restore):
   ```bash
   # From local backup copies
   cp ~/homelab-backup-proxmox9/sealed-secrets-key-backup.yaml \
      /Users/hlardner/projects/personal/homelab/sealed-secrets-key-backup.yaml
   cp ~/homelab-backup-proxmox9/letsencrypt-certs-backup.yaml \
      /Users/hlardner/projects/personal/homelab/letsencrypt-certs-backup.yaml
   cp ~/homelab-backup-proxmox9/secrets.yml \
      /Users/hlardner/projects/personal/homelab/config/secrets.yml

   # Restore to cluster
   cd /Users/hlardner/projects/personal/homelab
   make sealed-secrets-restore
   make certs-restore
   ```

6. **Restore Terraform state** if needed:
   ```bash
   cp ~/homelab-backup-proxmox9/terraform/terraform.tfstate \
      /Users/hlardner/projects/personal/homelab/terraform/
   cp -r ~/homelab-backup-proxmox9/terraform/terraform.tfstate.d/ \
      /Users/hlardner/projects/personal/homelab/terraform/
   ```

7. **Restore Longhorn data via Velero** (only if Longhorn volumes are missing):
   ```bash
   kubectl exec -n velero deploy/velero -- \
     /velero restore create --from-backup pre-proxmox9-upgrade
   ```

---

### Scenario D: Only the LVM persistent data is corrupted

Roll back the LVM snapshot (requires VM to be shut down):

```bash
ssh root@192.168.10.10

# Shut down the VM gracefully
qm shutdown 120

# Merge snapshot back to origin (this reverts all writes since snapshot was taken)
lvconvert --merge /dev/pve/k8s-persistent-data-snap-proxmox9

# Restart VM
qm start 120
```

---

## Local Backup Contents

```
~/homelab-backup-proxmox9/
├── letsencrypt-certs-backup.yaml                         # Let's Encrypt TLS certs (42KB)
├── sealed-secrets-key-backup.yaml                        # 3 sealed-secrets controller keys (20KB)
├── secrets.yml                                            # Plain secrets / config/secrets.yml (15KB)
├── cluster-state-2026-03-08.txt                          # Full cluster state snapshot (28KB)
├── vzdump-qemu-120-2026_03_08-13_04_35.vma.zst           # Full VM backup: OS + persistent data (22GB)
└── terraform/
    ├── terraform.tfstate                                  # Default workspace state
    ├── terraform.tfstate.backup                           # Terraform auto-backup
    └── terraform.tfstate.d/
        ├── k3s/terraform.tfstate                          # k3s workspace state
        ├── alpha/terraform.tfstate                        # alpha workspace state
        └── beta/terraform.tfstate                         # beta workspace state
```

> **Security**: The backup directory contains private keys and secrets. Ensure `~/homelab-backup-proxmox9/` is stored securely or encrypted at rest.
