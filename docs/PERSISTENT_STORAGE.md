# Persistent Storage for Longhorn

This document describes the persistent storage architecture that allows Longhorn data to survive Kubernetes cluster rebuilds.

## Storage Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Proxmox VE (pve Volume Group)                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────┐ │
│  │    root     │  │    swap     │  │    data (thin pool)      │ │
│  │    96GB     │  │    8GB      │  │        150GB             │ │
│  │  Proxmox OS │  │             │  │  VM OS disks (virtio0)   │ │
│  └─────────────┘  └─────────────┘  └──────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │              k8s-persistent-data (standalone LV)             ││
│  │                         200GB                                 ││
│  │           Longhorn data - SURVIVES CLUSTER REBUILDS          ││
│  └──────────────────────────────────────────────────────────────┘│
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Free Space (~22GB)                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Thin Pool vs Standalone LV

- **Thin Pool (`data`)**: Holds VM OS disks. When a VM is destroyed, its disk is deleted.
- **Standalone LV (`k8s-persistent-data`)**: Exists independently. When a VM is destroyed, the LV remains intact.

### Why Data Survives Rebuilds

1. The `k8s-persistent-data` LV is NOT part of the thin pool
2. Terraform attaches it via `qm set` after VM creation
3. When `terraform destroy` runs, the VM is removed but the LV stays
4. Next `terraform apply` re-attaches the same LV to the new VM

## Cluster Rebuild Workflow

### Before Destroying

No special steps required. The standalone LV is not tied to the VM lifecycle.

### Rebuild Process

```bash
# 1. Destroy the cluster (VMs only - persistent LV stays)
make destroy

# 2. Recreate VMs with persistent disk attached
cd terraform && terraform apply

# 3. Prep nodes (mounts persistent disk at /mnt/longhorn-data)
make node-prep

# 4. Install k3s
make k3s-install

# 5. Deploy bootstrap (MetalLB, Sealed Secrets, Longhorn, ArgoCD)
make deploy-bootstrap

# 6. Deploy services
make deploy-services
```

### After Rebuild

- Ansible detects the existing ext4 filesystem and skips formatting
- Longhorn discovers existing data at `/mnt/longhorn-data`
- PVCs reconnect to existing Longhorn volumes
- Garage data is preserved

## Longhorn Configuration

Longhorn uses two disks:

1. **default-disk** (`/var/lib/longhorn/`): On the VM's OS disk (thin pool). Ephemeral.
2. **persistent-data** (`/mnt/longhorn-data`): On the standalone LV. Persistent.

Use tags to control where volumes are scheduled:
- Volumes tagged `persistent` → persistent-data disk
- Other volumes → either disk

## Terraform Configuration

The persistent disk is attached via a `null_resource`:

```hcl
resource "null_resource" "attach_persistent_disk" {
  for_each = { for node in local.nodes : node.name => node }

  depends_on = [proxmox_virtual_environment_vm.node]

  provisioner "local-exec" {
    command = <<-EOT
      ssh root@${local.proxmox_host} \
        "qm set ${self.triggers.vm_id} --virtio1 /dev/pve/k8s-persistent-data,backup=1,iothread=1"
    EOT
  }
  # No destroy provisioner - LV stays intact
}
```

## Ansible Configuration

The `node-prep` role detects and mounts the disk:

```yaml
- name: Check if persistent data disk is already formatted
  command: blkid -o value -s TYPE /dev/vdb
  register: disk_fstype
  failed_when: false

- name: Format persistent data disk (only if unformatted)
  filesystem:
    fstype: ext4
    dev: /dev/vdb
    opts: -L k8s-data
  when: disk_fstype.rc != 0 or disk_fstype.stdout == ""

- name: Mount persistent data disk
  mount:
    path: /mnt/longhorn-data
    src: /dev/vdb
    fstype: ext4
    state: mounted
```

## Verification Commands

```bash
# Check LVM layout on Proxmox
ssh root@192.168.10.10 lvs
# Expected: data (150G thin), k8s-persistent-data (200G standard)

# Check mount on K8s node
ssh ubuntu@192.168.10.20 df -h /mnt/longhorn-data

# Check Longhorn disks
kubectl get nodes.longhorn.io -n longhorn-system -o yaml | grep -A5 "persistent-data"

# Check Longhorn storage usage
kubectl get settings -n longhorn-system default-data-path
```

## Storage Allocation

| Component | Size | Type | Notes |
|-----------|------|------|-------|
| Proxmox root | 96 GB | Standard LV | OS |
| Swap | 8 GB | Standard LV | Swap |
| Thin pool | 150 GB | Thin Pool | VM OS disks |
| **Persistent data** | **200 GB** | **Standard LV** | Longhorn/Garage |
| Free | ~22 GB | - | Buffer |

## Troubleshooting

### Disk Not Appearing in Longhorn

If the persistent disk doesn't appear after rebuild:

```bash
# Check if disk is mounted
ssh ubuntu@192.168.10.20 mount | grep longhorn

# Check Longhorn node spec
kubectl get nodes.longhorn.io -n longhorn-system homelab-node-0 -o yaml

# Add disk manually if needed
kubectl patch nodes.longhorn.io homelab-node-0 -n longhorn-system --type='json' \
  -p='[{"op": "add", "path": "/spec/disks/persistent-data", "value": {"allowScheduling": true, "path": "/mnt/longhorn-data"}}]'
```

### Volumes Stuck Pending

If volumes can't schedule:

```bash
# Check disk status
kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[0].status.diskStatus}'

# Check available storage
kubectl get nodes.longhorn.io -n longhorn-system -o jsonpath='{.items[0].status.diskStatus.persistent-data.storageAvailable}'
```

