# Kubernetes Manifests

This directory contains Kubernetes manifest files and Helm charts for deploying and managing services and applications on the K3s cluster.

## Deployment Architecture

### Minimal Bootstrap (Ansible - 4 Services)

These services are deployed via Ansible and must exist before ArgoCD can work:

| Service            | Why Bootstrap?                     |
| ------------------ | ---------------------------------- |
| **MetalLB**        | LoadBalancer IPs for ArgoCD access |
| **Longhorn**       | Persistent storage for ArgoCD      |
| **Sealed Secrets** | Decrypt secrets for ArgoCD apps    |
| **ArgoCD**         | The GitOps controller itself       |

### ArgoCD Managed (Everything Else)

All other services are deployed via ArgoCD with sync waves:

| Wave | Services                                                              | Purpose               |
| ---- | --------------------------------------------------------------------- | --------------------- |
| 1    | Cert-Manager                                                          | TLS foundation        |
| 2    | Traefik                                                               | Ingress controller    |
| 3    | Authelia, NetworkPolicies, ResourcePolicies                           | Security layer        |
| 4    | Loki, Promtail, Garage, Velero, Cloudflared, External-DNS, Intel GPU | Infrastructure        |
| 5    | Monitoring, Homepage, KEDA, KEDA HTTP                                 | Observability & UI    |
| 6    | Home Assistant, Node-RED, Zigbee2MQTT, Mosquitto                     | Home automation       |
| 7    | Plex, Filebrowser, Pi-hole, Forgejo, Quartz, Obsidian LiveSync, Headlamp | Applications      |

## Configuration Architecture

All configuration is centralized in `config/homelab.yaml` - the **single source of truth**.

```
config/
├── homelab.yaml    # All non-secret configuration
└── secrets.yml     # Secrets (gitignored)
```

Services are packaged as **Helm charts** that read values from `config/homelab.yaml`:

```
kubernetes/services/<service>/
├── Chart.yaml          # Helm chart definition
├── values.yaml         # Default values (overridden by config)
├── <app>-values.yaml   # Helm values for upstream chart (if applicable)
├── application.yaml    # ArgoCD Application manifest
└── templates/
    ├── certificate.yaml    # TLS certificate
    ├── ingressroute.yaml   # Traefik IngressRoute
    └── ...
```

**Note**: MetalLB and Sealed Secrets use Kustomize/values-only (no co-located Chart.yaml).

## Directory Structure

```
kubernetes/
├── README.md                    # This file
├── services/                    # Infrastructure services (supports cluster)
│   ├── argocd/                  # GitOps platform (Ansible + ArgoCD ingress)
│   ├── authelia/                # SSO/2FA authentication (Wave 3)
│   ├── cert-manager/            # TLS automation (Wave 1)
│   ├── cloudflared/             # Cloudflare tunnel (Wave 4)
│   ├── coredns/                 # CoreDNS custom configmap
│   ├── external-dns/            # Cloudflare DNS automation (Wave 4)
│   ├── garage/                  # S3-compatible object storage (Wave 4)
│   ├── intel-device-plugins/    # Intel GPU passthrough for media (Wave 4)
│   ├── loki/                    # Log aggregation (Wave 4)
│   ├── longhorn/                # Distributed block storage (Ansible + ArgoCD ingress)
│   ├── metallb/                 # MetalLB LoadBalancer (Ansible, Kustomize)
│   ├── network-policies/        # NetworkPolicies (Wave 3)
│   ├── promtail/                # Log collection (Wave 4)
│   ├── resource-policies/       # LimitRange/ResourceQuota (Wave 3)
│   ├── sealed-secrets/          # Secret encryption (Ansible)
│   ├── traefik/                 # Ingress controller (Wave 2)
│   └── velero/                  # Backup/restore to Garage S3 (Wave 4)
└── applications/                # Workloads (run on cluster)
    ├── root-app.yaml            # App-of-Apps — manages all */application.yaml
    ├── monitoring/              # Victoria Metrics + Grafana (Wave 5)
    ├── homepage/                # Homelab dashboard (Wave 5)
    ├── keda/                    # Kubernetes Event-Driven Autoscaler (Wave 5)
    ├── keda-http/               # KEDA HTTP add-on (Wave 5)
    ├── home-assistant/          # Home automation (Wave 6)
    ├── node-red/                # IoT flow automation (Wave 6, OIDC)
    ├── zigbee2mqtt/             # Zigbee coordinator via TCP (Wave 6)
    ├── mosquitto/               # MQTT broker (Wave 6)
    ├── plex/                    # Media server, Intel GPU, KEDA scaled (Wave 7)
    ├── filebrowser/             # Media upload UI (Wave 7)
    ├── pihole/                  # DNS ad-blocker @ 192.168.10.152 (Wave 7)
    ├── forgejo/                 # Self-hosted Git, KEDA scaled (Wave 7)
    ├── quartz/                  # Digital garden (Wave 7, public via Cloudflare Tunnel)
    ├── obsidian-livesync/       # CouchDB for Obsidian sync (Wave 7)
    └── headlamp/                # Kubernetes UI, KEDA scaled (Wave 7)
```

## Deployment Commands

### Full Deployment

```bash
# Bootstrap (Ansible) - MetalLB, Longhorn, Sealed Secrets, ArgoCD
make deploy-bootstrap

# Deploy all services via ArgoCD
make deploy-services

# Or do everything at once
make deploy-all
```

### GitOps — Deploy via ArgoCD

```bash
# Apply the App-of-Apps to kick off all ArgoCD-managed services
kubectl apply -f kubernetes/applications/root-app.yaml

# ArgoCD deploys everything in sync-wave order automatically
```

### Check Status

```bash
# ArgoCD applications
make apps-status
make apps-list

# Individual services
kubectl get pods -n <namespace>
kubectl get applications -n argocd
```

## Services

### Bootstrap Layer (Ansible)

| Service        | Namespace       | Description                |
| -------------- | --------------- | -------------------------- |
| MetalLB        | metallb-system  | LoadBalancer IP assignment |
| Longhorn       | longhorn-system | Distributed block storage  |
| Sealed Secrets | kube-system     | Secret encryption          |
| ArgoCD         | argocd          | GitOps platform            |

### Platform Services (ArgoCD)

| Service              | Wave | Namespace      | Description                          |
| -------------------- | ---- | -------------- | ------------------------------------ |
| Cert-Manager         | 1    | cert-manager   | TLS certificate automation           |
| Traefik              | 2    | traefik        | Ingress controller                   |
| Authelia             | 3    | authelia       | SSO/2FA authentication               |
| NetworkPolicies      | 3    | various        | Network isolation                    |
| ResourcePolicies     | 3    | various        | Resource limits                      |
| Loki                 | 4    | loki           | Log aggregation                      |
| Promtail             | 4    | loki           | Log collection                       |
| Garage               | 4    | garage         | S3-compatible storage (for Velero)   |
| Velero               | 4    | velero         | Backup and restore                   |
| Cloudflared          | 4    | cloudflared    | Cloudflare Tunnel (public: fallandrise only) |
| External-DNS         | 4    | external-dns   | Cloudflare DNS automation            |
| Intel Device Plugins | 4    | intel-device-plugins | GPU passthrough for Plex       |

### Applications (ArgoCD)

| Application      | Wave | Namespace          | Description                          |
| ---------------- | ---- | ------------------ | ------------------------------------ |
| Monitoring       | 5    | monitoring         | Victoria Metrics + Grafana           |
| Homepage         | 5    | homepage           | Homelab dashboard                    |
| KEDA             | 5    | keda               | Event-driven autoscaler              |
| KEDA HTTP        | 5    | keda               | HTTP-based scaling add-on            |
| Home Assistant   | 6    | home-assistant     | Home automation (OIDC via Authelia)  |
| Node-RED         | 6    | node-red           | IoT flow automation (OIDC)          |
| Zigbee2MQTT      | 6    | zigbee2mqtt        | Zigbee bridge via SMLIGHT TCP        |
| Mosquitto        | 6    | mosquitto          | MQTT broker                          |
| Plex             | 7    | plex               | Media server (Intel GPU, KEDA)       |
| Filebrowser      | 7    | plex               | Media upload UI (shares Plex PVC)    |
| Pi-hole          | 7    | pihole             | DNS ad-blocker (192.168.10.152)      |
| Forgejo          | 7    | forgejo            | Self-hosted Git (KEDA scaled)        |
| Quartz           | 7    | quartz             | Digital garden (public)              |
| Obsidian LiveSync | 7   | obsidian-livesync  | CouchDB for Obsidian sync            |
| Headlamp         | 7    | headlamp           | Kubernetes web UI (KEDA scaled)      |

## Access Points

After deployment, access services at:

| Service            | URL                                     |
| ------------------ | --------------------------------------- |
| ArgoCD             | https://argocd.silverseekers.org        |
| Grafana            | https://grafana.silverseekers.org       |
| Authelia           | https://auth.silverseekers.org          |
| Traefik            | https://traefik.silverseekers.org       |
| Longhorn           | https://longhorn.silverseekers.org      |
| Homepage           | https://home.silverseekers.org          |
| Home Assistant     | https://hass.silverseekers.org          |
| Node-RED           | https://node-red.silverseekers.org      |
| Plex               | https://plex.silverseekers.org          |
| Forgejo            | https://forgejo.silverseekers.org       |
| Pi-hole            | https://pihole.silverseekers.org        |
| Garage S3          | https://s3.silverseekers.org            |
| Quartz (public)    | https://fallandrise.silverseekers.org   |

## Configuration Changes

To change any service configuration:

1. Edit `config/homelab.yaml`
2. Commit and push to git
3. ArgoCD automatically syncs changes

```bash
git commit -am "Update service configuration"
git push
```

## Secrets

Secrets are managed via Sealed Secrets:

1. Add secrets to `config/secrets.yml`
2. Run `make seal-secrets`
3. Commit the sealed secrets to git

See [SECRETS.md](../SECRETS.md) for full documentation.

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
