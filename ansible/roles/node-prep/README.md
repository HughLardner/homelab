# Node Preparation Role

Prepares Ubuntu nodes for Kubernetes (K3s) deployment by configuring system settings, updating packages, and installing required utilities.

## Features

- ✅ **Package Management**: Update cache, upgrade packages, install essentials
- ✅ **Storage Support**: iSCSI and NFS packages for Longhorn persistent storage
- ✅ **iSCSI Services**: Automatic enablement of open-iscsi and iscsid
- ✅ **Multipath Configuration**: Prevents multipath conflicts with local disks
- ✅ **Kubernetes Prerequisites**: Configure sysctl, load kernel modules, disable swap
- ✅ **System Configuration**: Set hostname, timezone, locale, update /etc/hosts
- ✅ **Configurable**: Control what gets installed and configured via variables
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Optional Reboot**: Can automatically reboot after package upgrades

## Role Variables

### Package Management

```yaml
node_prep_upgrade_packages: true          # Run apt upgrade
node_prep_reboot_after_upgrade: false     # Auto-reboot after upgrade
```

### Package Lists

```yaml
# Always installed
node_prep_essential_packages:
  - curl
  - wget
  - ca-certificates
  - apt-transport-https
  - gnupg
  - lsb-release
  - software-properties-common

# Storage packages (for Longhorn)
node_prep_storage_packages:
  - open-iscsi       # iSCSI initiator (critical for Longhorn)
  - nfs-common       # NFS client support (for NFS backups)
  - apparmor-utils   # AppArmor profile management

# Optional utilities
node_prep_optional_packages:
  - htop
  - vim
  - jq
  - net-tools
  - dnsutils
  - iotop
  - tmux
  - iperf            # Network performance testing
```

### Kubernetes Configuration

```yaml
node_prep_configure_sysctl: true      # Configure kernel parameters
node_prep_load_kernel_modules: true   # Load overlay and br_netfilter
node_prep_disable_swap: true          # Disable swap (required for K8s)
```

### System Configuration

```yaml
node_prep_set_hostname: true          # Set hostname to inventory_hostname
node_prep_update_hosts: true          # Add cluster nodes to /etc/hosts
node_prep_configure_timezone: true    # Set system timezone
node_prep_timezone: "Europe/Ireland"  # Timezone to use
node_prep_configure_locale: true      # Set system locale
node_prep_locale: "en_IE.UTF-8"       # Locale to use
```

### Storage Configuration

```yaml
node_prep_enable_iscsi: true          # Enable iSCSI services (required for Longhorn)
node_prep_configure_multipath: true   # Configure multipath blacklist (prevents conflicts)
```

## Usage

### Basic Usage (in playbook)

```yaml
- name: Prepare Nodes
  hosts: k3s_cluster
  become: true
  gather_facts: true

  roles:
    - role: node-prep
```

### With K3s Installation

```yaml
- name: Prepare and Install K3s
  hosts: k3s_cluster
  become: true
  gather_facts: true

  roles:
    - role: node-prep
    - role: k3s
```

### Custom Configuration

```yaml
- name: Prepare Nodes (Custom)
  hosts: k3s_cluster
  become: true
  gather_facts: true

  roles:
    - role: node-prep
      vars:
        node_prep_upgrade_packages: true
        node_prep_reboot_after_upgrade: true  # Auto-reboot
        node_prep_optional_packages:          # Custom package list
          - htop
          - vim
          - ncdu
```

### Standalone Playbook

Create `playbooks/node-prep.yml`:

```yaml
---
- name: Prepare Nodes for Kubernetes
  hosts: k3s_cluster
  become: true
  gather_facts: true

  roles:
    - role: node-prep
```

Run it:
```bash
ansible-playbook playbooks/node-prep.yml
```

## What This Role Does

### 1. Package Management
- Updates apt cache
- Upgrades all packages (if enabled)
- Installs essential packages (curl, wget, ca-certificates, etc.)
- Installs storage packages (open-iscsi, nfs-common, apparmor-utils)
- Installs optional utilities (htop, vim, jq, iperf, etc.)

### 2. Storage Configuration (for Longhorn)
- Installs iSCSI initiator packages (open-iscsi)
- Enables and starts iSCSI services (open-iscsi, iscsid)
- Configures multipath blacklist to prevent conflicts with local disks
- Installs NFS client support for backup capabilities

### 3. Kubernetes Prerequisites
- Configures sysctl parameters:
  - `net.ipv4.ip_forward = 1`
  - `net.bridge.bridge-nf-call-iptables = 1`
  - `net.bridge.bridge-nf-call-ip6tables = 1`
- Loads kernel modules: `overlay`, `br_netfilter`
- Disables swap (required for Kubernetes)
- Removes swap entries from /etc/fstab

### 4. System Configuration
- Sets hostname to match inventory name
- Updates /etc/hosts with all cluster nodes
- Configures timezone (Europe/Ireland by default)
- Sets system locale (en_IE.UTF-8 by default)

### 5. Optional Reboot
- Reboots system after package upgrade (if enabled)
- Waits for system to come back online

## Requirements

- Ubuntu/Debian-based system
- SSH access with sudo privileges
- Ansible collection: `community.general` (for modprobe module)

Install required collection:
```bash
ansible-galaxy collection install community.general
```

## Examples

### Prepare nodes without upgrading packages

```bash
ansible-playbook playbooks/node-prep.yml \
  -e node_prep_upgrade_packages=false
```

### Prepare and auto-reboot

```bash
ansible-playbook playbooks/node-prep.yml \
  -e node_prep_reboot_after_upgrade=true
```

### Install minimal packages only

```bash
ansible-playbook playbooks/node-prep.yml \
  -e node_prep_optional_packages=[]
```

## Integration with K3s

This role is designed to run **before** K3s installation:

```yaml
---
# Full deployment playbook
- name: Prepare Nodes
  hosts: k3s_cluster
  become: true
  roles:
    - node-prep

- name: Install K3s First Master
  hosts: k3s_masters[0]
  become: true
  roles:
    - k3s

- name: Install K3s Additional Masters
  hosts: k3s_masters[1:]
  become: true
  roles:
    - k3s
```

## Makefile Integration

Add to your Makefile:

```makefile
node-prep:
	cd ansible && ansible-playbook playbooks/node-prep.yml

node-prep-reboot:
	cd ansible && ansible-playbook playbooks/node-prep.yml \
	  -e node_prep_reboot_after_upgrade=true

full-deploy: node-prep k3s-install
	@echo "✅ Full deployment complete!"
```

## Troubleshooting

### Package upgrade fails

```bash
# Check apt status on nodes
ansible k3s_cluster -m shell -a "apt update"

# Check for held packages
ansible k3s_cluster -m shell -a "apt-mark showhold"
```

### Kernel modules won't load

```bash
# Check if modules are available
ansible k3s_cluster -m shell -a "modprobe -n overlay"
ansible k3s_cluster -m shell -a "modprobe -n br_netfilter"
```

### Swap won't disable

```bash
# Check swap status
ansible k3s_cluster -m shell -a "swapon --show"

# Manually disable
ansible k3s_cluster -m shell -a "swapoff -a" -b
```

### iSCSI services won't start

```bash
# Check iSCSI service status
ansible k3s_cluster -m shell -a "systemctl status open-iscsi" -b
ansible k3s_cluster -m shell -a "systemctl status iscsid" -b

# Check iSCSI package installation
ansible k3s_cluster -m shell -a "dpkg -l | grep open-iscsi"

# Manually start services
ansible k3s_cluster -m shell -a "systemctl start open-iscsi && systemctl start iscsid" -b
```

### Multipath configuration issues

```bash
# Check if multipathd is installed
ansible k3s_cluster -m shell -a "systemctl status multipathd" -b

# Verify multipath configuration
ansible k3s_cluster -m shell -a "cat /etc/multipath.conf" -b

# Check multipath devices
ansible k3s_cluster -m shell -a "multipath -ll" -b
```

## Version History

- **v1.1**: Added storage support - iSCSI services, multipath configuration, NFS client (for Longhorn)
- **v1.0**: Initial release - Node preparation for K3s clusters

## License

Same as project license
