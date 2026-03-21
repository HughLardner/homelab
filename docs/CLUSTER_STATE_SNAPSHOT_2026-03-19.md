# Cluster State Snapshot — 2026-03-19

Point-in-time snapshot of the homelab cluster state. Use this as a reference for what's running and how it's structured.

> **Previous snapshot**: [CLUSTER_STATE_SNAPSHOT_2025-12-20.md](CLUSTER_STATE_SNAPSHOT_2025-12-20.md)

## Infrastructure

| Component | Details |
|-----------|---------|
| **Proxmox VE** | Version 9 (upgraded from v8, 2026-03-08 — see PRE_PROXMOX9_BACKUP.md) |
| **Node** | homelab-node-0 (VM 120) — 192.168.10.20 |
| **Resources** | 12GB RAM, 100GB OS disk, 200GB persistent LV (`/mnt/longhorn-data`) |
| **K3s** | Single-node cluster, kube-vip at 192.168.10.15 |
| **MetalLB Pool** | 192.168.10.150/28 (192.168.10.150-165) |
| **Traefik LB IP** | 192.168.10.150 |
| **Pi-hole IP** | 192.168.10.152 |

## Namespaces

| Namespace | Contents |
|-----------|----------|
| `argocd` | ArgoCD GitOps controller |
| `authelia` | Authelia SSO/2FA |
| `cert-manager` | TLS certificate automation |
| `cloudflared` | Cloudflare Tunnel daemon |
| `external-dns` | Cloudflare DNS automation |
| `forgejo` | Self-hosted Git server |
| `garage` | S3-compatible object storage |
| `headlamp` | Kubernetes web UI |
| `home-assistant` | Home automation |
| `homelab` (or `homepage`) | Homepage dashboard |
| `intel-device-plugins` | Intel GPU device plugin |
| ~~`keda`~~ | ~~KEDA autoscaler + HTTP add-on (REMOVED)~~ |
| `kube-system` | Sealed Secrets, CoreDNS, kube-vip |
| `longhorn-system` | Longhorn storage controller |
| `loki` | Loki log aggregation + Promtail |
| `metallb-system` | MetalLB LoadBalancer |
| `monitoring` | Victoria Metrics + Grafana |
| `mosquitto` | MQTT broker |
| `node-red` | IoT flow automation |
| `obsidian-livesync` | CouchDB for Obsidian sync |
| `pihole` | DNS ad-blocker |
| `plex` | Plex media server + Filebrowser |
| `quartz` | Digital garden + CouchDB client |
| `traefik` | Ingress controller |
| `velero` | Backup controller |
| `zigbee2mqtt` | Zigbee2MQTT bridge |

## Helm Releases

### Bootstrap (Ansible-deployed)

| Release | Namespace | Chart |
|---------|-----------|-------|
| metallb | metallb-system | metallb/metallb (Kustomize) |
| longhorn | longhorn-system | longhorn/longhorn |
| sealed-secrets | kube-system | sealed-secrets/sealed-secrets |
| argocd | argocd | argo/argo-cd |

### Platform Services (ArgoCD Wave 1–4)

| Release | Namespace | Wave | Notes |
|---------|-----------|------|-------|
| cert-manager | cert-manager | 1 | Cloudflare DNS challenge |
| traefik | traefik | 2 | 2 replicas, LB at 192.168.10.150 |
| authelia | authelia | 3 | SSO/2FA (Authentik evaluated, not active) |
| network-policies | various | 3 | Namespace isolation |
| resource-policies | various | 3 | LimitRange/ResourceQuota |
| loki | loki | 4 | 10Gi storage, 14d retention |
| promtail | loki | 4 | Log collector DaemonSet |
| garage | garage | 4 | S3 storage at s3.silverseekers.org |
| velero | velero | 4 | Daily backup (2am) to Garage S3 |
| cloudflared | cloudflared | 4 | Only fallandrise.silverseekers.org public |
| external-dns | external-dns | 4 | Cloudflare provider, sync policy |
| intel-device-plugins | intel-device-plugins | 4 | GPU passthrough |

### Applications (ArgoCD Wave 5+)

| Release | Namespace | Wave | Notes |
|---------|-----------|------|-------|
| monitoring | monitoring | 5 | VMSingle, VMAgent, VMAlert, Grafana |
| homepage | homepage | 5 | Proxmox + cluster dashboard |
| ~~keda~~ | ~~keda~~ | ~~5~~ | ~~Event-driven autoscaler (REMOVED)~~ |
| ~~keda-http~~ | ~~keda~~ | ~~5~~ | ~~HTTP scaling add-on (REMOVED)~~ |
| home-assistant | home-assistant | 6 | OIDC via Authelia, HACS |
| node-red | node-red | 6 | OIDC via Authelia |
| zigbee2mqtt | zigbee2mqtt | 6 | SMLIGHT SLZB TCP (192.168.40.185:7638) |
| mosquitto | mosquitto | 6 | MQTT broker (no public ingress) |
| plex | plex | 7 | Intel GPU, on-demand via HA toggle |
| pihole | pihole | 7 | 192.168.10.152, upstream: 1.1.1.1 |
| forgejo | forgejo | 7 | Self-hosted Git |
| quartz | quartz | 7 | Public at fallandrise.silverseekers.org |
| obsidian-livesync | obsidian-livesync | 7 | CouchDB for Obsidian plugin |
| headlamp | headlamp | 7 | Kubernetes web UI |

## ArgoCD Applications

All applications managed by the App-of-Apps pattern:

```
kubernetes/applications/root-app.yaml
  ├── kubernetes/services/*/application.yaml  (platform services)
  └── kubernetes/applications/*/application.yaml  (workloads)
```

Auto-prune and self-heal are enabled. ArgoCD syncs from `https://github.com/HughLardner/homelab.git`.

## On-Demand Applications

Plex defaults to `replicas: 0` and is toggled on/off via Home Assistant (`input_boolean.plex_server`).
All other applications (Forgejo, Headlamp, Grafana) run permanently with `replicas: 1`.

## Access Points

| Service | URL | Auth |
|---------|-----|------|
| ArgoCD | https://argocd.silverseekers.org | Authelia OIDC |
| Grafana | https://grafana.silverseekers.org | admin credentials |
| Authelia | https://auth.silverseekers.org | local users |
| Traefik | https://traefik.silverseekers.org | Authelia SSO |
| Longhorn | https://longhorn.silverseekers.org | Authelia SSO |
| Homepage | https://home.silverseekers.org | Authelia SSO |
| Home Assistant | https://hass.silverseekers.org | Authelia OIDC |
| Node-RED | https://node-red.silverseekers.org | Authelia OIDC |
| Zigbee2MQTT | https://zigbee2mqtt.silverseekers.org | Authelia SSO |
| Pi-hole | https://pihole.silverseekers.org | Authelia SSO |
| Plex | https://plex.silverseekers.org | Plex account |
| Filebrowser | https://files.silverseekers.org | Authelia SSO |
| Forgejo | https://forgejo.silverseekers.org | Forgejo accounts |
| Quartz | https://fallandrise.silverseekers.org | Public |
| Obsidian LiveSync | https://obsidian.silverseekers.org | CouchDB auth |
| Garage S3 | https://s3.silverseekers.org | S3 credentials |
| Headlamp | https://headlamp.silverseekers.org | Authelia SSO |

## Storage

| PVC / Purpose | Storage Class | Size | Notes |
|---------------|:-------------:|-----:|-------|
| VMSingle metrics | longhorn | 10Gi | 15-day retention |
| Grafana config | longhorn | 5Gi | |
| Alertmanager | longhorn | 2Gi | |
| Longhorn data path | (host) | 200GB | Proxmox LV `/mnt/longhorn-data`, survives rebuild |
| Loki logs | longhorn | 10Gi | 14-day retention |
| Garage S3 | longhorn | 50Gi | Velero backup target |
| Plex config | longhorn-retain | 20Gi | Survives PVC deletion |
| Plex media | longhorn | 100Gi | Future: migrate to NAS |
| Forgejo | longhorn | 10Gi | |
| Obsidian LiveSync | longhorn | 5Gi | |
| Home Assistant | longhorn | (managed by HA) | |
| Node-RED | longhorn | 2Gi | |
| Zigbee2MQTT | longhorn | 2Gi | |
| Pi-hole | longhorn | 1Gi | |

## Notable Configuration Details

- **Zigbee Coordinator**: SMLIGHT SLZB (CC2674P10) connected via TCP at `192.168.40.185:7638`
- **Public Exposure**: Only `fallandrise.silverseekers.org` is publicly accessible via Cloudflare Tunnel; all other services are internal
- **Cloudflare DNS**: External-DNS manages all `*.silverseekers.org` records automatically
- **Authentik**: Playbooks exist (`authentik*.yml`) from an evaluation period; **Authelia is the active SSO solution**
- **Proxmox 9 Upgrade**: Completed 2026-03-08 (see `docs/PRE_PROXMOX9_BACKUP.md` for backup checklist)
- **MinIO → Garage**: Migrated to Garage S3 storage (AGPL, homelab-optimized) in December 2025

## Known Issues / Limitations

- Plex media PVC is on Longhorn (slower than NAS). NAS migration planned when hardware arrives.
- VMSingle is single-replica (not horizontally scalable). Use VMCluster for HA metrics if needed.
- `ansible/inventory/hosts.yml` is an empty placeholder — generate with `make inventory` before running playbooks.
- Authentik playbooks (`authentik.yml`, `authentik-configure.yml`, `authentik-secrets.yml`) are present in `ansible/playbooks/` from a previous evaluation; they are not used in the current deployment.
