# Cluster State Snapshot — 2026-04-02

Point-in-time snapshot of the homelab cluster after the April 2026 drift review.

> **Previous snapshot**: [CLUSTER_STATE_SNAPSHOT_2026-03-19.md](CLUSTER_STATE_SNAPSHOT_2026-03-19.md)

## Infrastructure

| Component | Live State | Repo / Plan State |
|-----------|------------|-------------------|
| **Proxmox VE** | Version 9 | Matches docs |
| **Node** | `homelab-node-0` (VM 120) — `192.168.10.20` | Matches |
| **Memory** | `12248244Ki` allocatable (~12GB) | `config/homelab.yaml` now targets `14336` MB (14GB) |
| **Disk** | 100GB OS disk + 200GB persistent LV at `/mnt/longhorn-data` | Matches |
| **K3s** | Single-node cluster, `v1.33.5+k3s1` | Matches |
| **API VIP** | `192.168.10.15` | Matches |
| **MetalLB pool** | `192.168.10.150/28` | Matches |
| **Traefik LB IP** | `192.168.10.150` | Matches current config and README |
| **ArgoCD LB IP** | `192.168.10.151` | Live-only detail, not consistently documented |
| **Pi-hole DNS IP** | `192.168.10.152` | Matches |

## Namespaces

Current namespaces:

- `argocd`
- `authelia`
- `cert-manager`
- `cloudflared`
- `default`
- `external-dns`
- `forgejo`
- `garage`
- `headlamp`
- `home-assistant`
- `home-automation`
- `homepage`
- `inteldeviceplugins-system`
- `kube-node-lease`
- `kube-public`
- `kube-system`
- `loki`
- `longhorn-system`
- `media`
- `metallb-system`
- `monitoring`
- `obsidian-livesync`
- `pihole`
- `quartz`
- `traefik`
- `velero`

Drift from older docs:

- `home-automation` is active and hosts `otbr`, `python-matter-server`, `mosquitto`, `node-red`, and `zigbee2mqtt`.
- `media` is active for `plex`.
- `inteldeviceplugins-system` is the live namespace name, not `intel-device-plugins`.
- `kured` is now deployed and managed by ArgoCD.
- Older references to `keda` are no longer accurate.

## ArgoCD Applications

### Healthy and synced

- `argocd-ingress`
- `authelia`
- `cert-manager`
- `cloudflared`
- `external-dns`
- `forgejo`
- `garage`
- `headlamp`
- `home-assistant`
- `home-assistant-matter-hub`
- `homepage`
- `intel-device-plugins`
- `kured`
- `loki`
- `longhorn-ingress`
- `monitoring`
- `mosquitto`
- `network-policies`
- `node-red`
- `obsidian-livesync`
- `pihole`
- `plex`
- `promtail`
- `python-matter-server`
- `resource-policies`
- `traefik`
- `velero`
- `zigbee2mqtt`

### Residual non-green apps

| Application | State | Notes |
|-------------|-------|-------|
| `otbr` | `Synced / Degraded` | Container connects to `192.168.40.185:6638` but `otbr-agent` still fails with Spinel response timeouts. This now looks like an external radio / mode / session issue, not a repo port mismatch. |
| `quartz` | `Synced / Progressing` | Local repo now removes the blocking nginx init gate, but the live cluster still reflects the remote repo until those changes are pushed. |
| `root-app` | `OutOfSync / Healthy` | Temporary live patch was applied to `python-matter-server`'s child `Application` to suppress a known probe diff until the repo changes are pushed. |

## Workload Findings From This Review

### Fixed live during review

- `obsidian-livesync` was restored to `1/1` and now exposes a working service endpoint at `10.42.0.247:5984`.
- `python-matter-server` drift was traced to Helm rendering `enabled: true` inside probe objects; local repo now strips that field.
- `home-assistant-matter-hub` now runs successfully after replacing the invalid secret token with a valid Home Assistant token in the live generated `Secret`.

### Fixed in local repo, pending GitOps rollout

- `quartz` nginx no longer waits forever for a non-placeholder build artifact before starting.
- `quartz` is moved to a later sync wave so it waits for `obsidian-livesync`.
- `obsidian-livesync` init job hook now cleans up failed runs and has a longer deadline.
- `home-assistant-matter-hub` sealed secret in the repo has been regenerated locally with a valid token, but ArgoCD will not consume it until the repo changes are committed and pushed.

### Still unresolved

- `otbr` remains in `CrashLoopBackOff` with repeated `P-SpinelDrive-: Wait for response timeout` and `Platform------: Init() ... Failure` even while TCP port `6638` is reachable.

## LoadBalancer Services

| Namespace | Service | External IP | Notes |
|-----------|---------|-------------|-------|
| `traefik` | `traefik` | `192.168.10.150` | Main ingress |
| `argocd` | `argocd-server` | `192.168.10.151` | ArgoCD UI |
| `longhorn-system` | `longhorn-frontend` | `192.168.10.144` | Longhorn UI |
| `pihole` | `pihole-dns` | `192.168.10.152` | DNS service |

## Non-Running Pods

Expected / acceptable:

- Completed one-shot jobs in `default`, `inteldeviceplugins-system`, and `monitoring`

Not yet ideal:

- Quartz may still show an old init-stuck pod until ArgoCD reconciles to the updated repo state.

## Repo vs Live Drift Summary

| Area | Drift |
|------|-------|
| **Infrastructure sizing** | Repo targets 14GB RAM; live node is still ~12GB allocatable. |
| **Application inventory docs** | Older docs omit `home-assistant-matter-hub`, `otbr`, `python-matter-server`, `kured`, `home-automation`, and `media`. |
| **Quartz startup behavior** | Live cluster still follows remote repo; local repo now removes the deadlocking init flow. |
| **Matter Hub secret** | Live fix was applied directly to the generated `Secret`; repo-local sealed secret is updated but not yet rolled out through GitOps. |
| **Root app health** | Temporary live app patch keeps `python-matter-server` green until the repo changes land upstream. |

## Recommended Next Step

Commit and push the local repo changes so ArgoCD can reconcile:

- `python-matter-server` probe rendering fix
- `obsidian-livesync` hook cleanup
- `quartz` startup / sync-wave fixes
- refreshed `home-assistant-matter-hub` sealed secret
- updated docs and runbook
