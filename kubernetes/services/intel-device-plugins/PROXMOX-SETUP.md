# Proxmox iGPU Passthrough Setup for Plex QSV (PVE 9.1.6)

Tested on: **PVE 9.1.6 / kernel 6.17.13-1-pve / Intel Alder Lake-N iGPU (device ID 46d4)**
K3s VM: **Ubuntu 24.04 / kernel 6.17.0-14-generic (HWE)**

These steps must be completed on the Proxmox host and in the K3s VM **before** Plex
can use hardware transcoding.

---

## Step 1: Verify iGPU PCI Address

```bash
ssh root@proxmox01
lspci | grep -i VGA
# Expected: 00:02.0 VGA compatible controller: Intel Corporation Alder Lake-N ...
```

The address is almost always `0000:00:02` for Intel N-series. If different, update
`terraform/nodes.tf` `hostpci.id` accordingly.

> **Note on ROM files:** Intel N-series iGPUs do not expose a readable ROM via sysfs.
> `echo 1 > /sys/bus/pci/devices/0000:00:02.0/rom && cat ... > rom.bin` produces a
> **0-byte file** and an I/O error. A `romfile` is not required for QSV/compute-only
> passthrough — Plex only uses the encode/decode engines, not the display output.
> Do NOT set `romfile` in the `hostpci` config.

---

## Step 2: Check Current IOMMU State

```bash
cat /proc/cmdline
```

All of the following params must be present. If any are missing, proceed to Step 3:

```
intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=simplefb:off video=vesafb:off video=efifb:off video=vesa:off
```

| Parameter | Why it's needed |
|---|---|
| `intel_iommu=on` | Enables VT-d / IOMMU |
| `iommu=pt` | Passthrough mode — required for device passthrough |
| `initcall_blacklist=sysfb_init` | Prevents the framebuffer from claiming the iGPU at boot |
| `video=*:off` flags | Disables all host framebuffer drivers |

> After adding these params, `dmesg` will show:
> `pci 0000:00:02.0: DMAR: Skip IOMMU disabling for graphics`
> This is **expected and correct** — it means IOMMU is staying active for the iGPU.

---

## Step 3: Update GRUB Kernel Parameters

Check the current value first:

```bash
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
```

Update to add the missing params (adjust the `sed` to match your current value):

```bash
# Example: if current value is 'quiet intel_iommu=on'
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt initcall_blacklist=sysfb_init video=simplefb:off video=vesafb:off video=efifb:off video=vesa:off"/' /etc/default/grub

# Verify
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
```

Apply and reboot:

```bash
update-grub
reboot
```

> **proxmox-boot-tool:** On this system (GRUB-only boot), `update-grub` alone is sufficient.
> If your Proxmox uses EFI with proxmox-boot-tool, also run `proxmox-boot-tool refresh`
> before rebooting. Check by running: `test -f /etc/kernel/proxmox-boot-uuids && echo EFI || echo GRUB-only`

After reboot, confirm:

```bash
cat /proc/cmdline
# Must include: iommu=pt initcall_blacklist=sysfb_init video=simplefb:off ...

dmesg | grep -i "IOMMU enabled"
# Expected: DMAR: IOMMU enabled
```

---

## Step 4: Load VFIO Modules

Without VFIO, the iGPU stays bound to the host `i915` driver and the VM cannot claim it.

Check current state:

```bash
lsmod | grep vfio
# If this returns nothing, proceed
```

Add VFIO modules to load at boot:

```bash
cat >> /etc/modules <<'EOF'
vfio
vfio_iommu_type1
vfio_virqfd
EOF
```

Add a `softdep` so `vfio-pci` loads before `drm` (before `i915`):

```bash
cat > /etc/modprobe.d/vfio.conf <<'EOF'
softdep drm pre: vfio-pci
EOF
```

Rebuild initramfs:

```bash
update-initramfs -u -k all
```

Reboot:

```bash
reboot
```

After reboot, verify VFIO is loaded:

```bash
lsmod | grep vfio
# Expected:
#   vfio_pci               ...
#   vfio_pci_core          ...
#   vfio_iommu_type1       ...
#   vfio                   ...
```

---

## Step 5: Verify IOMMU Group

```bash
find /sys/kernel/iommu_groups/ -name "*00:02*"
# Expected: /sys/kernel/iommu_groups/0/devices/0000:00:02.0
```

---

## Step 6: Attach hostpci to the VM

The `hostpci` block is defined in `terraform/nodes.tf`. Since it is in
`lifecycle.ignore_changes`, Terraform will not modify it on existing VMs — use `qm set`:

```bash
# Check what's currently set
qm config 120 | grep hostpci

# Attach — NO romfile for Intel N-series
qm set 120 --hostpci0 0000:00:02,pcie=1,rombar=1

# Verify
qm config 120 | grep hostpci
# Expected: hostpci0: 0000:00:02,pcie=1,rombar=1
```

> **If `romfile=` is present in the config** (e.g. from a previous Terraform apply),
> the VM will fail silently — the GPU will not appear in the VM at all.
> Always remove it: `qm set 120 --hostpci0 0000:00:02,pcie=1,rombar=1`

---

## Step 7: Cold Reboot the VM

```bash
qm stop 120 && sleep 5 && qm start 120
```

Confirm VFIO claimed the device — you will see this in the output:

```
kvm: -device vfio-pci,host=0000:00:02.0,...: info: OpRegion detected on Intel display 46d4.
```

---

## Step 8: Install HWE Kernel in the K3s VM

**This is required.** The Ubuntu 24.04 default kernel (6.8.x) does NOT have device ID `46d4`
(Alder Lake-N) in its i915 PCI ID table. Even with the GPU visible via `lspci`, the i915
driver will load but produce zero output and bind to nothing.

Verify the issue first:

```bash
ssh ubuntu@192.168.10.20
modinfo i915 | grep -i "46d4"
# If this returns nothing, the default kernel doesn't support this GPU
```

Install the HWE kernel (6.17.x):

```bash
sudo apt install -y linux-generic-hwe-24.04
sudo reboot
```

After reboot, verify:

```bash
uname -r
# Expected: 6.17.0-14-generic (or newer)

lspci -v -s 01:00.0 | grep "Kernel driver"
# Expected: Kernel driver in use: i915

ls -la /dev/dri/
# Expected: card0  renderD128

sudo dmesg | grep -i i915 | head -3
# Expected: Found alderlake_p/alderlake_n (device ID 46d4) ...
```

---

## Step 9: Install VA-API Stack in the K3s VM

The Ubuntu 24.04 packaged `intel-media-va-driver-non-free` (v24.1.0) does NOT work with
kernel 6.17. The iHD driver silently fails to initialize. The fix is to install the VA-API
stack from Intel's official GPU repository.

```bash
# Add Intel GPU repository
curl -fsSL https://repositories.intel.com/gpu/intel-graphics.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
  https://repositories.intel.com/gpu/ubuntu noble client" | \
  sudo tee /etc/apt/sources.list.d/intel-graphics.list

sudo apt update

# Upgrade the full libva stack from Intel's repo
sudo apt install -y libva2 libva-drm2 vainfo intel-media-va-driver-non-free
```

Verify VA-API hardware acceleration works:

```bash
sudo vainfo --display drm
# Expected output:
#   vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 24.3.x
#   VAProfileH264Main    : VAEntrypointVLD
#   VAProfileH264Main    : VAEntrypointEncSlice
#   VAProfileHEVCMain    : VAEntrypointVLD
#   VAProfileHEVCMain    : VAEntrypointEncSlice
#   VAProfileAV1Profile0 : VAEntrypointVLD
```

> **GuC / HuC:** Verify firmware loaded correctly (required for encode):
> ```bash
> sudo dmesg | grep -i "guc\|huc"
> # Expected:
> #   GT0: HuC: authenticated for all workloads
> #   GT0: GUC: submission enabled
> ```

---

## Step 10: Fix render Group Access for Kubernetes

The Plex pod needs supplemental group membership to access `/dev/dri/renderD128`.
Check the actual render group GID on this node:

```bash
getent group render video
# Ubuntu 24.04 on this node: render:x:992, video:x:44
```

The Plex deployment's `supplementalGroups` must match. This is configured in
`kubernetes/applications/plex/values.yaml`:

```yaml
securityContext:
  supplementalGroups: [44, 992]  # video=44, render=992 on this node
```

Also add the ubuntu user to both groups (needed for manual vainfo testing):

```bash
sudo usermod -aG video,render ubuntu
# Takes effect on next SSH login
```

---

## Step 11: Verify Intel Device Plugin (after ArgoCD syncs)

```bash
# Check GpuDevicePlugin CR
kubectl get gpudeviceplugin -n inteldeviceplugins-system

# Confirm the resource is registered on the node
kubectl describe node homelab-node-0 | grep -A5 "Allocatable"
# Expected: gpu.intel.com/i915: 1

# Confirm Plex is using the GPU
kubectl describe pod -n plex -l app.kubernetes.io/name=plex | grep -A5 "Limits"
# Expected: gpu.intel.com/i915: 1
```

---

## Step 12: Verify Plex Hardware Transcoding

In the Plex Web UI:

1. **Settings → Transcoder** → enable "Use hardware acceleration when available"
2. Start a stream requiring transcoding (e.g. 4K HEVC → 1080p client)
3. Check **Now Playing** — codec should show `(hw)` suffix

Via logs:

```bash
kubectl logs -n plex -l app.kubernetes.io/name=plex --tail=50 | grep -i "transcode\|hardware\|QSV\|vaapi"
```

---

## Troubleshooting

| Symptom | Check |
|---|---|
| `/dev/dri` empty in VM | HWE kernel installed? `lspci -v \| grep "Kernel driver"` shows i915? |
| `modinfo i915 \| grep 46d4` returns nothing | HWE kernel not installed — still on 6.8.x |
| `qm config 120` shows `romfile=...` | Remove: `qm set 120 --hostpci0 0000:00:02,pcie=1,rombar=1` |
| `iHD_drv_video.so init failed` | VA-API stack too old — install from Intel GPU repo (Step 9) |
| `iHD_drv_video.so has no function __vaDriverInit_1_0` | libva2 too old — run full stack upgrade (Step 9) |
| VFIO not loading after reboot | Check `/etc/modules` and rerun `update-initramfs -u -k all` |
| `gpu.intel.com/i915` missing on node | Device plugin pod running? Node labelled `intel.feature.node.kubernetes.io/gpu=true`? |
| Plex not using hardware | Check `supplementalGroups` GIDs match node's render group (Step 10) |
| GuC/HuC not loaded | `sudo dmesg \| grep -i "guc\|huc"` — missing firmware? |
