# Proxmox iGPU Passthrough Setup for Plex QSV

These manual steps must be completed on the Proxmox host **before** running `terraform apply`
with the new `hostpci` block.

## Step 1: Find the iGPU PCI Address

SSH into the Proxmox host and identify the Intel iGPU:

```bash
ssh root@proxmox01
lspci | grep -i VGA
# Expected: 00:02.0 VGA compatible controller: Intel Corporation ...
```

The address is almost always `0000:00:02` for Intel N-series processors.
If different, update `terraform/nodes.tf` `hostpci.id` accordingly.

## Step 2: Enable IOMMU

Check if already enabled:
```bash
dmesg | grep -e DMAR -e IOMMU
```

If not enabled, add to GRUB:
```bash
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"/' /etc/default/grub
update-grub
reboot
```

After reboot, verify:
```bash
dmesg | grep -i "IOMMU enabled"
# Should show: DMAR: IOMMU enabled
```

## Step 3: Apply Terraform

From your local machine:
```bash
cd terraform
terraform apply
```

This adds `hostpci0` (the iGPU) to VM 120 without recreating it.
The VM will need a **cold reboot** after the hostpci is attached:
```bash
# Via Proxmox UI: Shutdown → Start VM 120
# Or via CLI:
qm stop 120 && qm start 120
```

## Step 4: Verify GPU in K3s VM

SSH into the K3s node and confirm the device is visible:
```bash
ssh ubuntu@192.168.10.20
ls -la /dev/dri/
# Should show: card0  card1  renderD128
```

If `/dev/dri` is empty or missing:
```bash
# Load i915 driver and make it persistent
echo "i915" | sudo tee -a /etc/modules
sudo modprobe i915
ls -la /dev/dri/
```

Install VA-API tools to verify hardware acceleration works:
```bash
sudo apt install -y intel-media-va-driver vainfo
vainfo
# Should show: VAEntrypointVLD, VAEntrypointEncSlice for H264/HEVC
```

## Step 5: Verify Device Plugin (after ArgoCD deploys)

Once the intel-device-plugins ArgoCD application has synced:
```bash
kubectl get gpudeviceplugin -n inteldeviceplugins-system
kubectl describe node homelab-node-0 | grep -i "gpu.intel.com"
# Should show: gpu.intel.com/i915: 1
```
