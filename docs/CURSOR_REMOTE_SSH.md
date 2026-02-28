# Editing Home Assistant Config with Cursor Remote SSH

This guide explains how to use Cursor's Remote SSH extension to edit Home Assistant configuration files running in Kubernetes.

## Quick Start

### 1. Install Remote SSH Extension

In Cursor, install the Cursor-compatible Remote SSH extension:

1. Open Extensions (`Cmd+Shift+X`)
2. Search for `@id:anysphere.remote-ssh`
3. Install the **Remote - SSH** extension by Anysphere

> **Note**: Use the Anysphere version, not Microsoft's - it's specifically maintained for Cursor compatibility.
> Reference: [Cursor Forum](https://forum.cursor.com/t/extesion-remote-ssh-problems/49056)

### 2. Configure SSH Host

Open the Command Palette (`Cmd+Shift+P`) and run:
```
Remote-SSH: Open SSH Configuration File
```

Add this entry to your `~/.ssh/config`:

```ssh
Host homelab-node-0
    HostName 192.168.10.20
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    # Optional: Keep connection alive
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### 3. Connect to the K8s Node

1. Open Command Palette (`Cmd+Shift+P`)
2. Run `Remote-SSH: Connect to Host...`
3. Select `homelab-node-0`
4. A new Cursor window opens, connected to your K8s node

### 4. Access Home Assistant Config

Once connected, use the pre-installed helper script:

```bash
# Pull the latest config from the pod
~/ha-edit.sh pull
```

Then in Cursor:
1. **File → Open Folder**
2. Navigate to `/home/ubuntu/ha-config`
3. Edit files with full Cursor features (syntax highlighting, YAML validation, AI assistance)

### 5. Push Changes Back

After editing, push your changes and restart HA:

```bash
# Validate YAML syntax first
~/ha-edit.sh validate

# Push changes and restart
~/ha-edit.sh push
```

## Helper Script Reference

The `~/ha-edit.sh` script is pre-installed on `homelab-node-0`:

| Command | Description |
|---------|-------------|
| `~/ha-edit.sh pull` | Copy config from pod to `~/ha-config` |
| `~/ha-edit.sh push` | Push local changes to pod (prompts for restart) |
| `~/ha-edit.sh shell` | Open bash shell directly in the HA pod |
| `~/ha-edit.sh status` | Show pod status and local config |
| `~/ha-edit.sh validate` | Check configuration.yaml YAML syntax |
| `~/ha-edit.sh logs` | Show recent Home Assistant logs |

### Typical Workflow

```bash
# 1. Get latest config
~/ha-edit.sh pull

# 2. Open in Cursor: File → Open Folder → /home/ubuntu/ha-config
#    Edit configuration.yaml, automations.yaml, etc.

# 3. Validate before pushing
~/ha-edit.sh validate

# 4. Push and restart
~/ha-edit.sh push
```

## Architecture Note

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Mac (Cursor)                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Remote SSH Extension                       │ │
│  └─────────────────────────┬──────────────────────────────┘ │
└────────────────────────────┼────────────────────────────────┘
                             │ SSH
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   homelab-node-0                             │
│                   192.168.10.20                              │
│                                                              │
│  ┌────────────────────┐    ┌────────────────────────────┐  │
│  │   ~/ha-config/     │◄───│  kubectl cp                 │  │
│  │   (local copy)     │    │  (sync files)               │  │
│  └────────────────────┘    └────────────┬───────────────┘  │
│                                          │                   │
└──────────────────────────────────────────┼──────────────────┘
                                           │ Kubernetes API
                                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 home-assistant-0 Pod                         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              /config (Longhorn PVC)                     │ │
│  │  - configuration.yaml                                   │ │
│  │  - automations.yaml                                     │ │
│  │  - scripts.yaml                                         │ │
│  │  - scenes.yaml                                          │ │
│  │  - custom_components/                                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### SSH Connection Failed

```bash
# Test SSH from your Mac
ssh ubuntu@192.168.10.20

# If password prompted, copy your key
ssh-copy-id ubuntu@192.168.10.20
```

### Pod Not Found

```bash
# Check pod status
kubectl get pods -n home-assistant

# If not running, check events
kubectl describe pod -n home-assistant home-assistant-0
```

### Permission Denied in Pod

```bash
# HA runs as user 1000, ensure correct ownership
kubectl exec -n home-assistant home-assistant-0 -- chown -R 1000:1000 /config
```

### Changes Not Taking Effect

After editing configuration.yaml, you must restart HA:

```bash
# Restart the StatefulSet
kubectl rollout restart statefulset -n home-assistant home-assistant

# Or via HA UI: Settings → System → Restart
```

## Future Enhancement: Direct SSH to Pod

For a better experience, we could add an SSH sidecar container to the Home Assistant pod. This would allow Cursor to connect directly to the container's filesystem without kubectl. However, this requires either:

1. Modifying the upstream Helm chart to support sidecars
2. Enabling Longhorn RWX storage (requires NFS)
3. Using Kustomize patches with ArgoCD

See [ADDING_APPLICATIONS.md](./ADDING_APPLICATIONS.md) for more on the chart structure.

