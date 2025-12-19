# Create VMs for the Kubernetes cluster
resource "proxmox_virtual_environment_vm" "node" {
  depends_on = [proxmox_virtual_environment_pool.operations_pool]
  for_each   = { for node in local.nodes : node.name => node }

  description = "Managed by Terraform"
  vm_id       = each.value.vm_id
  name        = each.value.name
  tags        = [local.cluster_config.cluster_name,"k3s"]
  node_name   = local.proxmox_node

  clone {
    vm_id     = local.template_vm_id
    full      = true
    retries   = 10
    node_name = local.proxmox_node
  }

  machine = "q35"

  cpu {
    cores   = each.value.cores
    sockets = 1
    numa    = true
    type    = each.value.cpu_type
    flags   = []
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    interface    = "virtio0"
    size         = each.value.disk_size
    datastore_id = "local-lvm"
    file_format  = "raw"
    backup       = true
    iothread     = true
    cache        = "none"
    aio          = "io_uring"
    discard      = "ignore"
    ssd          = false
  }

  # NOTE: Persistent data disk (virtio1) is attached separately via null_resource
  # This ensures the standalone LV survives terraform destroy

  agent {
    enabled = true
    timeout = "15m"
    trim    = true
    type    = "virtio"
  }

  vga {
    memory = 16
    type   = "serial0"
  }

  initialization {
    interface = "ide2"

    user_account {
      keys     = var.vm_ssh_key
      password = var.vm_password
      username = var.vm_username
    }

    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/24"
        gateway = local.cluster_config.gateway
      }
    }

    dns {
      domain  = "lan"
      servers = local.cluster_config.dns_servers
    }
  }

  network_device {
    bridge   = "vmbr0"
    firewall = false
  }

  reboot          = false
  stop_on_destroy = true
  migrate         = false  # Single host, no migration
  on_boot         = true
  started         = true
  pool_id         = upper(local.cluster_config.cluster_name)

  lifecycle {
    ignore_changes = [
      tags,
      description,
      clone,
      machine,
      operating_system,
      # Changes to initialization will recreate the VM!
      initialization,
      # Protect against accidental disk recreation
      disk,
    ]
  }
}

# Attach persistent data disk to VMs
# This disk is a standalone LV (not in thin pool) and survives VM destruction
# The LV must be created manually on Proxmox first: lvcreate -L 200G -n k8s-persistent-data pve
resource "null_resource" "attach_persistent_disk" {
  for_each = { for node in local.nodes : node.name => node }

  depends_on = [proxmox_virtual_environment_vm.node]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.node[each.key].vm_id
  }

  # Attach the persistent LV to the VM as virtio1
  # Using SSH to Proxmox to run qm set command
  provisioner "local-exec" {
    command = <<-EOT
      echo "Attaching persistent data disk to VM ${self.triggers.vm_id}..."
      ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} \
        "qm set ${self.triggers.vm_id} --virtio1 /dev/pve/k8s-persistent-data,backup=1,iothread=1"
      echo "Persistent data disk attached successfully"
    EOT
  }

  # On destroy: do NOT detach the disk - it will be detached automatically when VM is destroyed
  # The LV itself survives because it's a standalone LV, not a thin pool volume
}

# Manage SSH known_hosts for VMs
resource "null_resource" "ssh_known_hosts_management" {
  for_each = { for node in local.nodes : node.name => node }

  depends_on = [proxmox_virtual_environment_vm.node]

  triggers = {
    vm_id      = proxmox_virtual_environment_vm.node[each.key].id
    ip_address = each.value.ip_address
  }

  # Add SSH host key when VM is created
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for SSH to be available (max 120 seconds)
      for i in {1..24}; do
        if ssh-keyscan -H ${each.value.ip_address} >> ~/.ssh/known_hosts 2>/dev/null; then
          echo "SSH host key added for ${each.value.ip_address}"
          break
        fi
        echo "Waiting for SSH on ${each.value.ip_address}... (attempt $i/24)"
        sleep 5
      done
    EOT
  }

  # Remove SSH host key when VM is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = "ssh-keygen -R ${self.triggers.ip_address} 2>/dev/null || true"
  }
}
