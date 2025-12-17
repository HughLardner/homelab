# Kubernetes Manifests

This directory contains Kubernetes manifest files and Helm charts for deploying and managing services and applications on your K3s clusters.

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

| Wave | Services                                                 | Purpose            |
| ---- | -------------------------------------------------------- | ------------------ |
| 1    | Cert-Manager                                             | TLS foundation     |
| 2    | Traefik                                                  | Ingress controller |
| 3    | Authelia, NetworkPolicies, LimitRanges                   | Security layer     |
| 4    | Loki, Promtail, MinIO, Velero, Cloudflared, External-DNS | Infrastructure     |
| 5    | Monitoring                                               | Applications       |

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

## Directory Structure

```
kubernetes/
├── README.md                    # This file
├── applications/                # Workloads (run on cluster)
│   ├── root-app.yaml            # App-of-Apps pattern
│   └── monitoring/              # Victoria Metrics + Grafana (Helm chart)
│       ├── Chart.yaml
│       ├── application.yaml
│       ├── values.yaml
│       ├── templates/
│       └── README.md
└── services/                    # Infrastructure services (supports cluster)
    ├── metallb/                 # MetalLB LoadBalancer (Ansible)
    ├── longhorn/                # Distributed block storage (Ansible + ArgoCD ingress)
    ├── sealed-secrets/          # Secret encryption (Ansible)
    ├── argocd/                  # GitOps platform (Ansible + ArgoCD ingress)
    ├── cert-manager/            # TLS automation (Wave 1)
    ├── traefik/                 # Ingress controller (Wave 2)
    ├── authelia/                # SSO/2FA authentication (Wave 3)
    ├── network-policies/        # NetworkPolicies (Wave 3)
    ├── resource-policies/       # LimitRange/ResourceQuota (Wave 3)
    ├── loki/                    # Log aggregation (Wave 4)
    ├── promtail/                # Log collector (Wave 4)
    ├── minio/                   # Object storage (Wave 4)
    ├── velero/                  # Backup/restore (Wave 4)
    ├── cloudflared/             # Cloudflare Tunnel (Wave 4)
    └── external-dns/            # DNS automation (Wave 4)
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

| Service          | Wave | Namespace    | Description                |
| ---------------- | ---- | ------------ | -------------------------- |
| Cert-Manager     | 1    | cert-manager | TLS certificate automation |
| Traefik          | 2    | traefik      | Ingress controller         |
| Authelia         | 3    | authelia     | SSO/2FA authentication     |
| NetworkPolicies  | 3    | various      | Network isolation          |
| ResourcePolicies | 3    | various      | Resource limits            |
| Loki             | 4    | loki         | Log aggregation            |
| Promtail         | 4    | loki         | Log collector              |
| MinIO            | 4    | minio        | S3-compatible storage      |
| Velero           | 4    | velero       | Backup and restore         |
| Cloudflared      | 4    | cloudflared  | External access tunnel     |
| External-DNS     | 4    | external-dns | DNS automation             |

### Applications (ArgoCD)

| Application | Wave | Namespace  | Description                |
| ----------- | ---- | ---------- | -------------------------- |
| Monitoring  | 5    | monitoring | Victoria Metrics + Grafana |

## Access Points

After deployment, access services at:

| Service       | URL                                     |
| ------------- | --------------------------------------- |
| ArgoCD        | https://argocd.silverseekers.org        |
| Grafana       | https://grafana.silverseekers.org       |
| Authelia      | https://auth.silverseekers.org          |
| Traefik       | https://traefik.silverseekers.org       |
| Longhorn      | https://longhorn.silverseekers.org      |
| MinIO Console | https://minio-console.silverseekers.org |

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

## References

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
