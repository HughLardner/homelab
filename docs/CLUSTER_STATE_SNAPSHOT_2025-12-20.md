# Homelab Cluster State Snapshot

**Generated:** 2025-12-20 01:20 UTC  
**Cluster Uptime:** ~1 hour (fresh deployment)  
**Status:** 🟢 Healthy

---

## Table of Contents

- [Infrastructure Overview](#infrastructure-overview)
- [Cluster Configuration](#cluster-configuration)
- [Namespaces](#namespaces)
- [Helm Releases](#helm-releases)
- [ArgoCD Applications](#argocd-applications)
- [Pod Status Summary](#pod-status-summary)
- [Services](#services)
- [Storage](#storage)
- [Certificates](#certificates)
- [Network Configuration](#network-configuration)
- [Resource Usage](#resource-usage)
- [Known Issues](#known-issues)
- [Secrets Reference](#secrets-reference)

---

## Change Log

| Date       | Change                                                         |
| ---------- | -------------------------------------------------------------- |
| 2025-12-20 | Fresh cluster deployment with all services healthy             |
| 2025-12-20 | All certificates now using letsencrypt-prod                    |
| 2025-12-18 | Migrated from MinIO to Garage for S3-compatible object storage |
| 2025-12-18 | Velero backup solution deployed and healthy                    |

---

## Infrastructure Overview

### K3s Node

| Name           | IP            | OS               | Kernel | Container Runtime | Kubelet      |
| -------------- | ------------- | ---------------- | ------ | ----------------- | ------------ |
| homelab-node-0 | 192.168.10.20 | Ubuntu 24.04 LTS | 6.8.0  | containerd://2.x  | v1.33.x+k3s1 |

**Node Resources:**

- CPU: 4 cores (~260m used, 6.5%)
- Memory: 12GB (4.8GB working set, ~40% used)
- Storage: 103GB (90GB available, 87% free)
- Pod Capacity: 110 pods (56 running, 51%)
- Pod CIDR: 10.42.0.0/24

**Node Roles:** control-plane, etcd, master

**K3s Config Flags:**

- `--cluster-init`
- `--disable traefik`
- `--disable servicelb`
- `--write-kubeconfig-mode 644`
- `--tls-san 192.168.10.20`

---

## Cluster Configuration

**API Server:** https://192.168.10.20:6443

**CNI:** Flannel (VXLAN)

---

## Namespaces

| Namespace       | Age | Purpose                      | Pods |
| --------------- | --- | ---------------------------- | ---- |
| argocd          | ~1h | GitOps deployment            | 5    |
| authelia        | ~1h | Authentication portal        | 1    |
| cert-manager    | ~1h | TLS certificate management   | 3    |
| cloudflared     | ~1h | Cloudflare tunnel            | 1    |
| default         | ~1h | Default namespace            | 0    |
| external-dns    | ~1h | DNS automation               | 1    |
| garage          | ~1h | S3-compatible object storage | 1    |
| homepage        | ~1h | Dashboard                    | 1    |
| kube-node-lease | ~1h | Node heartbeat               | 0    |
| kube-public     | ~1h | Public resources             | 0    |
| kube-system     | ~1h | System components            | 4    |
| loki            | ~1h | Log aggregation              | 3    |
| longhorn-system | ~1h | Distributed storage          | 15   |
| metallb-system  | ~1h | LoadBalancer                 | 2    |
| monitoring      | ~1h | Victoria Metrics + Grafana   | 8    |
| traefik         | ~1h | Ingress controller           | 1    |
| velero          | ~1h | Backup solution              | 2    |

**Total Namespaces:** 17

---

## Helm Releases

| Release            | Namespace       | Chart                     | Version | Status      |
| ------------------ | --------------- | ------------------------- | ------- | ----------- |
| argocd             | argocd          | argo-cd                   | 7.7.10  | deployed ✅ |
| argocd-ingress     | argocd          | argocd-ingress            | 1.0.0   | deployed ✅ |
| authelia           | authelia        | authelia                  | 0.9.0   | deployed ✅ |
| authelia-ingress   | authelia        | authelia-ingress          | 1.0.0   | deployed ✅ |
| cert-manager       | cert-manager    | cert-manager              | v1.17.1 | deployed ✅ |
| cloudflared        | cloudflared     | cloudflared               | 0.1.0   | deployed ✅ |
| external-dns       | external-dns    | external-dns              | 1.15.0  | deployed ✅ |
| garage-release     | garage          | garage                    | 0.1.0   | deployed ✅ |
| grafana            | monitoring      | grafana                   | 8.8.2   | deployed ✅ |
| homepage           | homepage        | homepage                  | 0.1.0   | deployed ✅ |
| kube-state-metrics | monitoring      | kube-state-metrics        | 5.27.0  | deployed ✅ |
| loki               | loki            | loki                      | 6.24.1  | deployed ✅ |
| longhorn           | longhorn-system | longhorn                  | 1.8.1   | deployed ✅ |
| longhorn-ingress   | longhorn-system | longhorn-ingress          | 1.0.0   | deployed ✅ |
| metallb            | metallb-system  | metallb                   | 0.14.9  | deployed ✅ |
| node-exporter      | monitoring      | prometheus-node-exporter  | 4.43.1  | deployed ✅ |
| promtail           | loki            | promtail                  | 6.16.6  | deployed ✅ |
| sealed-secrets     | kube-system     | sealed-secrets            | 2.15.1  | deployed ✅ |
| traefik            | traefik         | traefik                   | 28.0.0  | deployed ✅ |
| traefik-ingress    | traefik         | traefik-ingress           | 1.0.0   | deployed ✅ |
| velero             | velero          | velero                    | 8.3.0   | deployed ✅ |
| vm-operator        | monitoring      | victoria-metrics-operator | 0.40.1  | deployed ✅ |

**Total Helm Releases:** 22 (all deployed successfully)

---

## ArgoCD Applications

| Application       | Sync Status | Health     | Notes              |
| ----------------- | ----------- | ---------- | ------------------ |
| argocd-ingress    | Synced ✅   | Healthy ✅ | ArgoCD UI ingress  |
| authelia          | Synced ✅   | Healthy ✅ | SSO portal         |
| cert-manager      | Synced ✅   | Healthy ✅ | TLS automation     |
| cloudflared       | Synced ✅   | Healthy ✅ | CF tunnel          |
| external-dns      | Synced ✅   | Healthy ✅ | DNS automation     |
| garage            | Synced ✅   | Healthy ✅ | S3 storage         |
| homepage          | Synced ✅   | Healthy ✅ | Dashboard          |
| loki              | Synced ✅   | Healthy ✅ | Log aggregation    |
| longhorn-ingress  | Synced ✅   | Healthy ✅ | Storage UI         |
| monitoring        | Synced ✅   | Healthy ✅ | Metrics stack      |
| network-policies  | Synced ✅   | Healthy ✅ | Network isolation  |
| promtail          | Synced ✅   | Healthy ✅ | Log collection     |
| resource-policies | Synced ✅   | Healthy ✅ | Resource limits    |
| root-app          | Synced ✅   | Healthy ✅ | App-of-Apps        |
| traefik           | Synced ✅   | Healthy ✅ | Ingress controller |
| velero            | Synced ✅   | Healthy ✅ | Backup solution    |

**Total Applications:** 16 (all synced and healthy)

---

## Pod Status Summary

### All Pods Running ✅

**Total: 56 pods (all Running, 0 restarts)**

#### argocd (5 pods)

| Pod                                 | Status     | Restarts | CPU | Memory |
| ----------------------------------- | ---------- | -------- | --- | ------ |
| argocd-application-controller-0     | Running ✅ | 0        | 9m  | 292Mi  |
| argocd-applicationset-controller-\* | Running ✅ | 0        | 1m  | 23Mi   |
| argocd-redis-\*                     | Running ✅ | 0        | 5m  | 8Mi    |
| argocd-repo-server-\*               | Running ✅ | 0        | 1m  | 41Mi   |
| argocd-server-\*                    | Running ✅ | 0        | 1m  | 65Mi   |

#### authelia (1 pod)

| Pod         | Status     | Restarts | CPU | Memory |
| ----------- | ---------- | -------- | --- | ------ |
| authelia-\* | Running ✅ | 0        | 1m  | 91Mi   |

#### cert-manager (3 pods)

| Pod                        | Status     | Restarts | CPU | Memory |
| -------------------------- | ---------- | -------- | --- | ------ |
| cert-manager-\*            | Running ✅ | 0        | 1m  | 31Mi   |
| cert-manager-cainjector-\* | Running ✅ | 0        | 1m  | 31Mi   |
| cert-manager-webhook-\*    | Running ✅ | 0        | 1m  | 12Mi   |

#### cloudflared (1 pod)

| Pod            | Status     | Restarts | CPU | Memory |
| -------------- | ---------- | -------- | --- | ------ |
| cloudflared-\* | Running ✅ | 0        | 3m  | 14Mi   |

#### external-dns (1 pod)

| Pod             | Status     | Restarts | CPU | Memory |
| --------------- | ---------- | -------- | --- | ------ |
| external-dns-\* | Running ✅ | 0        | 1m  | 21Mi   |

#### garage (1 pod)

| Pod      | Status     | Restarts | CPU | Memory |
| -------- | ---------- | -------- | --- | ------ |
| garage-0 | Running ✅ | 0        | 1m  | 2Mi    |

#### homepage (1 pod)

| Pod         | Status     | Restarts | CPU | Memory |
| ----------- | ---------- | -------- | --- | ------ |
| homepage-\* | Running ✅ | 0        | 1m  | 100Mi  |

#### kube-system (4 pods)

| Pod                          | Status     | Restarts | CPU | Memory |
| ---------------------------- | ---------- | -------- | --- | ------ |
| coredns-\*                   | Running ✅ | 0        | 2m  | 17Mi   |
| local-path-provisioner-\*    | Running ✅ | 0        | 1m  | 8Mi    |
| metrics-server-\*            | Running ✅ | 0        | 5m  | 23Mi   |
| sealed-secrets-controller-\* | Running ✅ | 0        | 1m  | 11Mi   |

#### loki (3 pods)

| Pod            | Status     | Restarts | CPU | Memory |
| -------------- | ---------- | -------- | --- | ------ |
| loki-0         | Running ✅ | 0        | 9m  | 118Mi  |
| loki-canary-\* | Running ✅ | 0        | 2m  | 14Mi   |
| promtail-\*    | Running ✅ | 0        | 16m | 48Mi   |

#### longhorn-system (15 pods)

| Pod                         | Status     | Restarts | CPU | Memory |
| --------------------------- | ---------- | -------- | --- | ------ |
| csi-attacher-\* (3)         | Running ✅ | 0        | 3m  | 23Mi   |
| csi-provisioner-\* (3)      | Running ✅ | 0        | 3m  | 28Mi   |
| csi-resizer-\* (3)          | Running ✅ | 0        | 3m  | 23Mi   |
| csi-snapshotter-\* (3)      | Running ✅ | 0        | 4m  | 23Mi   |
| engine-image-\*             | Running ✅ | 0        | 7m  | 19Mi   |
| instance-manager-\*         | Running ✅ | 0        | 27m | 135Mi  |
| longhorn-csi-plugin-\*      | Running ✅ | 0        | 2m  | 28Mi   |
| longhorn-driver-deployer-\* | Running ✅ | 0        | 1m  | 12Mi   |
| longhorn-manager-\*         | Running ✅ | 0        | 11m | 96Mi   |
| longhorn-ui-\* (2)          | Running ✅ | 0        | 2m  | 4Mi    |

#### metallb-system (2 pods)

| Pod           | Status     | Restarts | CPU | Memory |
| ------------- | ---------- | -------- | --- | ------ |
| controller-\* | Running ✅ | 0        | 1m  | 33Mi   |
| speaker-\*    | Running ✅ | 0        | 3m  | 18Mi   |

#### monitoring (8 pods)

| Pod                   | Status     | Restarts | CPU | Memory |
| --------------------- | ---------- | -------- | --- | ------ |
| grafana-\*            | Running ✅ | 0        | 7m  | 259Mi  |
| kube-state-metrics-\* | Running ✅ | 0        | 1m  | 14Mi   |
| node-exporter-\*      | Running ✅ | 0        | 4m  | 10Mi   |
| vm-operator-\*        | Running ✅ | 0        | 5m  | 27Mi   |
| vmagent-\*            | Running ✅ | 0        | 14m | 62Mi   |
| vmalert-\*            | Running ✅ | 0        | 2m  | 6Mi    |
| vmalertmanager-\*     | Running ✅ | 0        | 1m  | 16Mi   |
| vmsingle-\*           | Running ✅ | 0        | 21m | 241Mi  |

#### traefik (1 pod)

| Pod        | Status     | Restarts | CPU | Memory |
| ---------- | ---------- | -------- | --- | ------ |
| traefik-\* | Running ✅ | 0        | 1m  | 63Mi   |

#### velero (2 pods)

| Pod           | Status     | Restarts | CPU | Memory |
| ------------- | ---------- | -------- | --- | ------ |
| node-agent-\* | Running ✅ | 0        | 1m  | 17Mi   |
| velero-\*     | Running ✅ | 0        | 1m  | 53Mi   |

---

## Services

### LoadBalancer Services (External IPs)

| Service           | Namespace       | External IP    | Ports   |
| ----------------- | --------------- | -------------- | ------- |
| traefik           | traefik         | 192.168.10.145 | 80, 443 |
| longhorn-frontend | longhorn-system | 192.168.10.144 | 80      |

### ClusterIP Services

| Service           | Namespace    | Ports      | Purpose          |
| ----------------- | ------------ | ---------- | ---------------- |
| argocd-server     | argocd       | 80, 443    | ArgoCD UI        |
| authelia          | authelia     | 80         | Auth portal      |
| cert-manager      | cert-manager | 9402       | Cert management  |
| external-dns      | external-dns | 7979       | DNS automation   |
| garage            | garage       | 3900       | S3 API           |
| garage-admin      | garage       | 3903       | Admin API        |
| garage-web        | garage       | 3902       | Web interface    |
| homepage          | homepage     | 3000       | Dashboard        |
| kube-dns          | kube-system  | 53, 9153   | DNS              |
| loki              | loki         | 3100, 9095 | Log aggregation  |
| grafana           | monitoring   | 80         | Monitoring UI    |
| vmsingle-vmsingle | monitoring   | 8429       | Victoria Metrics |

---

## Storage

### Storage Classes

| Name       | Provisioner           | Reclaim Policy | Default | Volume Expansion |
| ---------- | --------------------- | -------------- | ------- | ---------------- |
| local-path | rancher.io/local-path | Delete         | Yes     | No               |
| longhorn   | driver.longhorn.io    | Delete         | Yes     | Yes              |

### Persistent Volume Claims

| PVC                                 | Namespace  | Storage Class | Capacity | Status   |
| ----------------------------------- | ---------- | ------------- | -------- | -------- |
| authelia                            | authelia   | longhorn      | 1Gi      | Bound ✅ |
| data-garage-0                       | garage     | longhorn      | 50Gi     | Bound ✅ |
| meta-garage-0                       | garage     | longhorn      | 1Gi      | Bound ✅ |
| storage-loki-0                      | loki       | local-path    | 10Gi     | Bound ✅ |
| grafana                             | monitoring | local-path    | 5Gi      | Bound ✅ |
| vmalertmanager-vmalertmanager-db-\* | monitoring | local-path    | 1Gi      | Bound ✅ |
| vmsingle-vmsingle                   | monitoring | local-path    | 2Gi      | Bound ✅ |

**Total Storage:** ~70Gi allocated across 7 PVCs

---

## Certificates

### ClusterIssuers

| Name                | Ready   | Status                  |
| ------------------- | ------- | ----------------------- |
| letsencrypt-prod    | True ✅ | ACME account registered |
| letsencrypt-staging | True ✅ | ACME account registered |
| selfsigned          | True ✅ | Ready                   |

### Certificates (All Using letsencrypt-prod)

| Certificate           | Namespace       | Ready   | Secret                |
| --------------------- | --------------- | ------- | --------------------- |
| argocd-server-tls     | argocd          | True ✅ | argocd-server-tls     |
| authelia-tls          | authelia        | True ✅ | authelia-tls          |
| garage-tls            | garage          | True ✅ | garage-tls            |
| homepage-tls          | homepage        | True ✅ | homepage-tls          |
| longhorn-frontend-tls | longhorn-system | True ✅ | longhorn-frontend-tls |
| grafana-tls           | monitoring      | True ✅ | grafana-tls           |
| traefik-dashboard-tls | traefik         | True ✅ | traefik-dashboard-tls |

**Note:** All certificates are now using `letsencrypt-prod` with trusted browser certificates.

---

## Network Configuration

### MetalLB

**IP Address Pool:** 192.168.10.150/28 (192.168.10.144 - 192.168.10.159)

- Auto Assign: Enabled
- Mode: L2 Advertisement

**Currently Assigned:**

- 192.168.10.144 → Longhorn UI
- 192.168.10.145 → Traefik

### Traefik IngressRoutes

| Route             | Namespace       | Service              |
| ----------------- | --------------- | -------------------- |
| argocd-server     | argocd          | ArgoCD Server        |
| authelia          | authelia        | Authelia             |
| garage-s3         | garage          | Garage S3 API        |
| garage-web        | garage          | Garage Web Interface |
| homepage          | homepage        | Homepage Dashboard   |
| longhorn-frontend | longhorn-system | Longhorn UI          |
| grafana           | monitoring      | Grafana              |
| traefik-dashboard | traefik         | Traefik Dashboard    |

---

## Resource Usage

### Node Resource Usage

| Metric               | Usage  | Capacity | Percentage |
| -------------------- | ------ | -------- | ---------- |
| CPU                  | 155m   | 4000m    | 4%         |
| Memory (working set) | 4.8Gi  | 12Gi     | 40%        |
| Memory (available)   | 7.7Gi  | 12Gi     | 64%        |
| Storage              | 12.6Gi | 103Gi    | 12%        |
| Swap                 | 0Mi    | 0Mi      | -          |

### Top Pod Resource Consumers (CPU)

| Pod                           | Namespace       | CPU | Memory |
| ----------------------------- | --------------- | --- | ------ |
| instance-manager              | longhorn-system | 27m | 135Mi  |
| vmsingle-vmsingle             | monitoring      | 21m | 241Mi  |
| promtail                      | loki            | 16m | 48Mi   |
| vmagent                       | monitoring      | 14m | 53Mi   |
| longhorn-manager              | longhorn-system | 11m | 96Mi   |
| argocd-application-controller | argocd          | 9m  | 292Mi  |
| loki-0                        | loki            | 9m  | 118Mi  |

### Top Pod Resource Consumers (Memory)

| Pod                           | Namespace       | Memory | CPU |
| ----------------------------- | --------------- | ------ | --- |
| argocd-application-controller | argocd          | 292Mi  | 9m  |
| grafana (all containers)      | monitoring      | 259Mi  | 7m  |
| vmsingle-vmsingle             | monitoring      | 241Mi  | 21m |
| longhorn instance-manager     | longhorn-system | 135Mi  | 27m |
| loki-0                        | loki            | 118Mi  | 9m  |
| homepage                      | homepage        | 100Mi  | 1m  |
| longhorn-manager              | longhorn-system | 96Mi   | 11m |

**Total Pod Resources:** 155m CPU, 2208Mi Memory

---

## Known Issues

### ✅ All Clear

No current issues detected:

- All pods running with 0 restarts
- All ArgoCD applications synced and healthy
- All certificates valid (letsencrypt-prod)
- All PVCs bound
- No resource pressure on node

### Previous Issues (Resolved)

| Issue                     | Status      | Resolution                   |
| ------------------------- | ----------- | ---------------------------- |
| VMAgent restarting        | ✅ Resolved | Fresh deployment, 0 restarts |
| Cert-Manager sync unknown | ✅ Resolved | Now synced and healthy       |
| Garage OutOfSync          | ✅ Resolved | Now synced and healthy       |
| Staging certificates      | ✅ Resolved | Switched to letsencrypt-prod |

---

## Secrets Reference

**Important:** These are just secret names for reference. Actual secret values are stored in:

- `/Users/hlardner/projects/personal/homelab/config/secrets.yml`
- Sealed secrets in the repository

### Critical Secrets

| Secret                         | Namespace    | Type              | Keys                       |
| ------------------------------ | ------------ | ----------------- | -------------------------- |
| argocd-initial-admin-secret    | argocd       | Opaque            | password                   |
| argocd-repo-creds-github-https | argocd       | Opaque            | type, url, password        |
| authelia-secrets               | authelia     | Opaque            | JWT, HMAC, encryption keys |
| authelia-users                 | authelia     | Opaque            | users_database.yml         |
| cloudflare-api-token           | cert-manager | Opaque            | api-token                  |
| cloudflared-tunnel-token       | cloudflared  | Opaque            | token                      |
| external-dns-cloudflare-token  | external-dns | Opaque            | api-token                  |
| garage-credentials             | garage       | Opaque            | access-key, secret-key     |
| grafana-admin-secret           | monitoring   | Opaque            | admin-user, admin-password |
| sealed-secrets-key             | kube-system  | kubernetes.io/tls | tls.crt, tls.key           |
| velero-credentials             | velero       | Opaque            | cloud credentials          |

---

## StatefulSets

| StatefulSet                   | Namespace  | Replicas | Storage                         |
| ----------------------------- | ---------- | -------- | ------------------------------- |
| argocd-application-controller | argocd     | 1/1      | None                            |
| garage                        | garage     | 1/1      | 50Gi data + 1Gi meta (Longhorn) |
| loki                          | loki       | 1/1      | 10Gi (local-path)               |
| vmalertmanager-vmalertmanager | monitoring | 1/1      | 1Gi (local-path)                |

---

## DaemonSets

| DaemonSet           | Namespace       | Pods | Purpose             |
| ------------------- | --------------- | ---- | ------------------- |
| loki-canary         | loki            | 1/1  | Log validation      |
| promtail            | loki            | 1/1  | Log collection      |
| engine-image-ei-\*  | longhorn-system | 1/1  | Longhorn engine     |
| longhorn-csi-plugin | longhorn-system | 1/1  | CSI plugin          |
| longhorn-manager    | longhorn-system | 1/1  | Storage management  |
| speaker             | metallb-system  | 1/1  | L2 announcer        |
| node-exporter       | monitoring      | 1/1  | Node metrics        |
| node-agent          | velero          | 1/1  | Velero backup agent |

---

## Access Points

| Service       | URL                                | Notes             |
| ------------- | ---------------------------------- | ----------------- |
| **ArgoCD**    | https://argocd.silverseekers.org   | GitOps dashboard  |
| **Grafana**   | https://grafana.silverseekers.org  | Monitoring        |
| **Traefik**   | https://traefik.silverseekers.org  | Ingress dashboard |
| **Authelia**  | https://auth.silverseekers.org     | SSO portal        |
| **Homepage**  | https://home.silverseekers.org     | Dashboard         |
| **Longhorn**  | https://longhorn.silverseekers.org | Storage UI        |
| **Garage S3** | https://s3.silverseekers.org       | S3 API            |

---

## End of Snapshot

This document captures the state of the homelab cluster as of 2025-12-20 01:20 UTC.
All configuration files are stored in Git and secrets in `config/secrets.yml`.

**Cluster Health:** 🟢 Healthy (all systems operational)
