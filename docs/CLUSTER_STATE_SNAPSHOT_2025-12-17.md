# Homelab Cluster State Snapshot

**Generated:** 2025-12-17 23:49 UTC  
**Last Updated:** 2025-12-18 07:50 UTC  
**Cluster Age:** 2d 8h  
**Purpose:** Pre-rebuild documentation

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

| Date | Change |
|------|--------|
| 2025-12-18 | Migrated from MinIO to Garage for S3-compatible object storage |
| 2025-12-18 | Velero backup solution now deployed and healthy |

---

## Infrastructure Overview

### Proxmox VMs
| VM Name | ID | Node | Status | CPU | Memory | Uptime |
|---------|-----|------|--------|-----|--------|--------|
| homelab-node-0 | 120 | proxmox01 | running | 12.7% | 11.07GB/12GB | 1d 23h 55m |
| ubuntu-cloud-template | 900 | proxmox01 | stopped | - | - | - |
| k8s-ready-template | 9000 | proxmox01 | stopped | - | - | - |

### K3s Node
| Name | IP | OS | Kernel | Container Runtime | Kubelet |
|------|-----|-----|--------|-------------------|---------|
| homelab-node-0 | 192.168.10.20 | Ubuntu 24.04.3 LTS | 6.8.0-88-generic | containerd://2.1.4-k3s1 | v1.33.5+k3s1 |

**Node Resources:**
- CPU: 4 cores
- Memory: 12GB (12,248,248 Ki allocatable)
- Storage: 97GB ephemeral storage
- Pod Capacity: 110 pods
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

| Namespace | Age | Purpose |
|-----------|-----|---------|
| argocd | 2d7h | GitOps deployment |
| authelia | 2d7h | Authentication portal |
| cert-manager | 2d7h | TLS certificate management |
| cloudflared | 30h | Cloudflare tunnel |
| default | 2d8h | Default namespace |
| external-dns | 29h | DNS automation |
| garage | 6h53m | S3-compatible object storage (replaced MinIO) |
| homepage | 17h | Dashboard |
| kube-node-lease | 2d8h | Node heartbeat |
| kube-public | 2d8h | Public resources |
| kube-system | 2d8h | System components |
| loki | 30h | Log aggregation |
| longhorn-system | 2d8h | Distributed storage |
| metallb-system | 2d8h | LoadBalancer |
| ~~minio~~ | ~~23h~~ | ~~Object storage~~ **(Deprecated - replaced by Garage)** |
| monitoring | 44h | Victoria Metrics + Grafana |
| traefik | 2d7h | Ingress controller |
| velero | 30h | Backup solution ✅ |

---

## Helm Releases

| Release | Namespace | Chart | Version | App Version | Status |
|---------|-----------|-------|---------|-------------|--------|
| argocd | argocd | argo-cd | 7.7.10 | v2.13.2 | deployed |
| argocd-ingress | argocd | argocd-ingress | 1.0.0 | 2.9 | deployed |
| authelia | authelia | authelia | 0.9.0 | 4.38.9 | deployed |
| authelia-ingress | authelia | authelia-ingress | 1.0.0 | 4.38 | deployed |
| cloudflared | cloudflared | cloudflared | 0.1.0 | 2024.1.0 | deployed |
| longhorn-ingress | longhorn-system | longhorn-ingress | 1.0.0 | 1.6 | deployed |
| sealed-secrets | kube-system | sealed-secrets | 2.15.1 | 0.26.1 | deployed |
| traefik | traefik | traefik | 28.0.0 | v3.0.0 | deployed |
| traefik-ingress | traefik | traefik-ingress | 1.0.0 | 3.0 | deployed |

**Note:** Garage is deployed via ArgoCD (not Helm).

---

## ArgoCD Applications

| Application | Sync Status | Health | Notes |
|-------------|-------------|--------|-------|
| argocd-ingress | Synced | Healthy | ✅ |
| authelia | Synced | Healthy | ✅ |
| cert-manager | Unknown | Healthy | ⚠️ Sync status unknown |
| cloudflared | Synced | Healthy | ✅ |
| external-dns | Synced | Healthy | ✅ |
| garage | OutOfSync | Healthy | ⚠️ S3 object storage (replaced MinIO) |
| homepage | Synced | Healthy | ✅ |
| loki | Synced | Healthy | ✅ |
| longhorn-ingress | Synced | Healthy | ✅ |
| monitoring | Synced | Healthy | ✅ |
| network-policies | Synced | Healthy | ✅ |
| promtail | Synced | Healthy | ✅ |
| resource-policies | Synced | Healthy | ✅ |
| root-app | Synced | Healthy | ✅ App-of-Apps pattern |
| traefik | Synced | Healthy | ✅ |
| velero | Synced | Healthy | ✅ Backup solution working |

---

## Pod Status Summary

### All Pods Running ✅

**Total: 54 pods (all Running)**

#### argocd (5 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| argocd-application-controller-0 | Running | 0 | 39h |
| argocd-applicationset-controller-fd979c6d4-rtdcj | Running | 0 | 40h |
| argocd-redis-64bcbd4d76-pjsp8 | Running | 0 | 40h |
| argocd-repo-server-568b666f45-vhxhs | Running | 0 | 39h |
| argocd-server-5f467677f8-rwfqt | Running | 0 | 39h |

#### authelia (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| authelia-677b48fddb-jxvxv | Running | 0 | 17h |

#### cert-manager (3 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| cert-manager-6b6fb948c9-ffzff | Running | 0 | 2d7h |
| cert-manager-cainjector-7b49c96b7b-v9thl | Running | 0 | 2d7h |
| cert-manager-webhook-6ff9d5cf4b-zbnhw | Running | 0 | 2d7h |

#### cloudflared (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| cloudflared-7cd6648896-l2s7l | Running | 2 (29h ago) | 29h |

#### external-dns (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| external-dns-fcd8b45f-lqlmg | Running | 0 | 24h |

#### garage (1 pod) - **NEW**
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| garage-0 | Running | 0 | 8m |

#### homepage (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| homepage-79c8cdf798-7ghfq | Running | 0 | 8h |

#### kube-system (4 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| coredns-659f584bfd-dvpfc | Running | 0 | 2d7h |
| local-path-provisioner-774c6665dc-xq5p9 | Running | 0 | 2d8h |
| metrics-server-7bfffcd44-8r4wp | Running | 0 | 2d8h |
| sealed-secrets-controller-bd6746fd7-4z992 | Running | 0 | 2d7h |

#### loki (3 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| loki-0 | Running | 0 | 30h |
| loki-canary-lc9ql | Running | 0 | 30h |
| promtail-s9ld7 | Running | 0 | 23h |

#### longhorn-system (15 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| csi-attacher-58b6c6fdf6-* (3) | Running | various | 2d8h |
| csi-provisioner-74f57b955d-* (3) | Running | various | 2d8h |
| csi-resizer-6cfcbf5f5-* (3) | Running | 0 | 2d8h |
| csi-snapshotter-5fcb76449-* (3) | Running | 0 | 2d8h |
| engine-image-ei-acb7590c-kxc64 | Running | 0 | 2d8h |
| instance-manager-d5f89eeb3f965a8a18536620faebd2d2 | Running | 0 | 2d8h |
| longhorn-csi-plugin-l4955 | Running | 0 | 2d8h |
| longhorn-driver-deployer-7586c8d85b-z8kgz | Running | 0 | 2d8h |
| longhorn-manager-mlwhz | Running | 1 (2d8h ago) | 2d8h |
| longhorn-ui-77d4995f67-* (2) | Running | 0 | 2d8h |

#### metallb-system (2 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| controller-bb5f47665-rf627 | Running | 0 | 2d8h |
| speaker-xmgcb | Running | 0 | 2d8h |

#### monitoring (7 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| grafana-5c58bf9c5b-wglt8 | Running | 0 | 30h |
| kube-state-metrics-57db796588-jzcqv | Running | 0 | 37h |
| node-exporter-prometheus-node-exporter-5jv9x | Running | 0 | 37h |
| vm-operator-victoria-metrics-operator-785b7bcd7-h52xp | Running | 0 | 37h |
| vmagent-vmagent-c4768f65d-l6mzx | Running | 44 (74m ago) | 40h |
| vmalert-vmalert-858db5945b-4d46v | Running | 0 | 40h |
| vmalertmanager-vmalertmanager-0 | Running | 0 | 40h |
| vmsingle-vmsingle-69965db646-9bsjp | Running | 0 | 40h |

#### traefik (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| traefik-66f58dfb9c-tv9z2 | Running | 0 | 8h |

#### velero (2 pods) - **NOW WORKING**
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| velero-6cfcd8b98f-9jg4n | Running | 0 | 3m |
| node-agent-82k6r | Running | 0 | 3m |

---

## Services

### LoadBalancer Services (External IPs)

| Service | Namespace | External IP | Ports |
|---------|-----------|-------------|-------|
| traefik | traefik | 192.168.10.145 | 80, 443 |
| longhorn-frontend | longhorn-system | 192.168.10.144 | 80 |

### ClusterIP Services

| Service | Namespace | Cluster IP | Ports | Purpose |
|---------|-----------|------------|-------|---------|
| argocd-server | argocd | 10.43.171.7 | 80, 443 | ArgoCD UI |
| authelia | authelia | 10.43.192.175 | 80 | Auth portal |
| cert-manager | cert-manager | 10.43.168.185 | 9402 | Cert management |
| external-dns | external-dns | 10.43.248.79 | 7979 | DNS automation |
| garage | garage | 10.43.134.46 | 3900 | S3 API |
| garage-admin | garage | 10.43.201.76 | 3903 | Garage admin API |
| garage-web | garage | 10.43.247.231 | 3902 | Garage web interface |
| garage-headless | garage | None | 3901 | StatefulSet headless |
| homepage | homepage | 10.43.66.31 | 3000 | Dashboard |
| kube-dns | kube-system | 10.43.0.10 | 53, 9153 | DNS |
| loki | loki | 10.43.91.78 | 3100, 9095 | Log aggregation |
| grafana | monitoring | 10.43.163.176 | 80 | Monitoring UI |
| vmsingle-vmsingle | monitoring | 10.43.251.38 | 8429 | Victoria Metrics |
| kube-state-metrics | monitoring | 10.43.135.182 | 8080 | K8s metrics |

---

## Storage

### Storage Classes
| Name | Provisioner | Reclaim Policy | Default | Volume Expansion |
|------|-------------|----------------|---------|------------------|
| local-path | rancher.io/local-path | Delete | Yes | No |
| longhorn | driver.longhorn.io | Delete | Yes | Yes |
| longhorn-fast | driver.longhorn.io | Delete | No | Yes |
| longhorn-retain | driver.longhorn.io | Retain | No | Yes |

### Persistent Volume Claims
| PVC | Namespace | Storage Class | Capacity | Status |
|-----|-----------|---------------|----------|--------|
| authelia | authelia | longhorn | 1Gi | Bound |
| data-garage-0 | garage | longhorn | 50Gi | Bound |
| meta-garage-0 | garage | longhorn | 1Gi | Bound |
| storage-loki-0 | loki | longhorn | 10Gi | Bound |
| grafana | monitoring | local-path | 5Gi | Bound |
| vmalertmanager-vmalertmanager-db-vmalertmanager-vmalertmanager-0 | monitoring | local-path | 1Gi | Bound |
| vmsingle-vmsingle | monitoring | local-path | 2Gi | Bound |

### Persistent Volumes
| PV | Capacity | Status | Claim | Storage Class |
|----|----------|--------|-------|---------------|
| pvc-513b8b36-d02f-49b1-8f4c-087a41f3a313 | 1Gi | Bound | authelia/authelia | longhorn |
| pvc-961bc648-4c79-42eb-ac60-6bb0b6f37a34 | 50Gi | Bound | garage/data-garage-0 | longhorn |
| pvc-3647e591-de64-45ef-91d6-62924c5c677b | 1Gi | Bound | garage/meta-garage-0 | longhorn |
| pvc-9f16ca19-af8c-47d6-a2d1-3e55b65479e6 | 10Gi | Bound | loki/storage-loki-0 | longhorn |
| pvc-f7470eb9-f0fb-4565-b613-a52cca41e7fa | 5Gi | Bound | monitoring/grafana | local-path |
| pvc-420a1217-2f8d-44fd-843d-6f03211d2e1b | 1Gi | Bound | monitoring/vmalertmanager | local-path |
| pvc-7a7c9591-cf70-4b1c-b890-000709d97496 | 2Gi | Bound | monitoring/vmsingle | local-path |

**Note:** All PVs with `Delete` reclaim policy will be lost on PVC deletion.

---

## Certificates

### ClusterIssuers
| Name | Ready | Status |
|------|-------|--------|
| letsencrypt-prod | True | ACME account registered |
| letsencrypt-staging | True | ACME account registered |
| selfsigned | True | Ready |

### Certificates
| Certificate | Namespace | Issuer | Ready | Secret |
|-------------|-----------|--------|-------|--------|
| argocd-server-tls | argocd | letsencrypt-staging | True | argocd-server-tls |
| authelia-tls | authelia | letsencrypt-staging | True | authelia-tls |
| garage-tls | garage | letsencrypt-staging | True | garage-tls |
| homepage-tls | homepage | letsencrypt-staging | True | homepage-tls |
| longhorn-frontend-tls | longhorn-system | letsencrypt-staging | True | longhorn-frontend-tls |
| grafana-tls | monitoring | letsencrypt-staging | True | grafana-tls |
| traefik-dashboard-tls | traefik | letsencrypt-staging | True | traefik-dashboard-tls |

**Note:** All certificates are using `letsencrypt-staging`. Switch to `letsencrypt-prod` for production.

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
| Route | Namespace | Service |
|-------|-----------|---------|
| argocd-server | argocd | ArgoCD Server |
| authelia | authelia | Authelia |
| garage-s3 | garage | Garage S3 API |
| garage-web | garage | Garage Web Interface |
| homepage | homepage | Homepage Dashboard |
| longhorn-frontend | longhorn-system | Longhorn UI |
| grafana | monitoring | Grafana |
| traefik-dashboard | traefik | Traefik Dashboard |

---

## Resource Usage

### Node Resource Usage
| Metric | Usage | Percentage |
|--------|-------|------------|
| CPU | 317m | 7% |
| Memory | 5822Mi | 48% |
| Swap | 0Mi | - |

### Top Pod Resource Consumers
| Pod | CPU | Memory |
|-----|-----|--------|
| vmsingle-vmsingle | 9m | 419Mi |
| argocd-application-controller | 6m | 304Mi |
| instance-manager (Longhorn) | 33m | 176Mi |
| longhorn-manager | 11m | 113Mi |
| loki | 16m | 109Mi |
| homepage | 1m | 99Mi |
| grafana | 9m | 82Mi |
| garage | TBD | TBD |

**Total Pod Resources:** ~152m CPU, ~2400Mi Memory

---

## Known Issues

### ⚠️ VMAgent Restarting
- **Pod:** vmagent-vmagent-c4768f65d-l6mzx
- **Restarts:** 44 (most recent 74m ago)
- **Action Required:** Check vmagent logs for configuration issues

### ⚠️ Cert-Manager Sync Status Unknown
- **Application:** cert-manager
- **Status:** Unknown (but Health: Healthy)
- **Action Required:** May need manual sync or investigation

### ⚠️ Garage OutOfSync
- **Application:** garage
- **Status:** OutOfSync (but Health: Healthy)
- **Note:** Recently deployed, may need sync

### ⚠️ Cloudflared Restarts
- **Pod:** cloudflared-7cd6648896-l2s7l
- **Restarts:** 2 (29h ago)
- **Status:** Currently stable

### ⚠️ Staging Certificates
- All certificates using `letsencrypt-staging`
- Not trusted by browsers
- **Action Required:** Switch to `letsencrypt-prod` after rebuild

### ✅ RESOLVED: Velero Deployment
- **Previous Status:** OutOfSync, Health: Missing
- **Current Status:** Synced, Healthy
- **Pods Running:** velero, node-agent

---

## Secrets Reference

**Important:** These are just secret names for reference. Actual secret values are stored in:
- `/Users/hlardner/projects/personal/homelab/config/secrets.yml`
- Sealed secrets in the repository

### Critical Secrets

| Secret | Namespace | Type | Keys |
|--------|-----------|------|------|
| argocd-initial-admin-secret | argocd | Opaque | password |
| argocd-repo-creds-github-https | argocd | Opaque | type, url, password |
| argocd-oidc-secret | argocd | Opaque | oidc.github.clientSecret |
| authelia-secrets | authelia | Opaque | JWT, HMAC, encryption keys |
| authelia-users | authelia | Opaque | users_database.yml |
| cloudflare-api-token | cert-manager | Opaque | api-token |
| cloudflared-tunnel-token | cloudflared | Opaque | token |
| external-dns-cloudflare-token | external-dns | Opaque | api-token |
| garage-credentials | garage | Opaque | access-key, secret-key |
| grafana-admin-secret | monitoring | Opaque | admin-user, admin-password |
| grafana-oidc-secret | monitoring | Opaque | clientSecret |
| sealed-secrets-keyb5jmm | kube-system | kubernetes.io/tls | tls.crt, tls.key |
| letsencrypt-prod-account-key | cert-manager | Opaque | tls.key |
| letsencrypt-staging-account-key | cert-manager | Opaque | tls.key |
| velero-repo-credentials | velero | Opaque | repository password |

---

## ConfigMaps Reference

### Application Configurations
| ConfigMap | Namespace | Data Keys |
|-----------|-----------|-----------|
| homepage-config | homepage | 9 config files |
| authelia | authelia | configuration.yaml |
| loki | loki | loki config |
| grafana | monitoring | grafana.ini sections |
| coredns | kube-system | Corefile |

### Grafana Dashboards
| ConfigMap | Namespace |
|-----------|-----------|
| grafana-dashboard-argocd | monitoring |
| grafana-dashboard-cert-manager | monitoring |
| grafana-dashboard-loki-logs | monitoring |
| grafana-dashboard-longhorn | monitoring |
| grafana-dashboard-traefik | monitoring |

---

## StatefulSets

| StatefulSet | Namespace | Replicas | Storage |
|-------------|-----------|----------|---------|
| argocd-application-controller | argocd | 1/1 | None |
| garage | garage | 1/1 | 50Gi data + 1Gi meta (Longhorn) |
| loki | loki | 1/1 | 10Gi (Longhorn) |
| vmalertmanager-vmalertmanager | monitoring | 1/1 | 1Gi (local-path) |

---

## DaemonSets

| DaemonSet | Namespace | Pods | Purpose |
|-----------|-----------|------|---------|
| longhorn-iscsi-installation | default | 1/1 | iSCSI daemon |
| loki-canary | loki | 1/1 | Log validation |
| promtail | loki | 1/1 | Log collection |
| engine-image-ei-acb7590c | longhorn-system | 1/1 | Longhorn engine |
| longhorn-csi-plugin | longhorn-system | 1/1 | CSI plugin |
| longhorn-manager | longhorn-system | 1/1 | Storage management |
| speaker | metallb-system | 1/1 | L2 announcer |
| node-exporter-prometheus-node-exporter | monitoring | 1/1 | Node metrics |
| node-agent | velero | 1/1 | Velero backup agent |

---

## Rebuild Checklist

When rebuilding, ensure these components are deployed in order:

1. **Infrastructure Layer**
   - [ ] MetalLB (LoadBalancer)
   - [ ] Longhorn (Storage)
   - [ ] Sealed Secrets (Secret management)

2. **Core Services**
   - [ ] Cert-Manager + ClusterIssuers
   - [ ] Traefik (Ingress)

3. **GitOps**
   - [ ] ArgoCD + Repository credentials
   - [ ] Root app deployment

4. **Applications** (via ArgoCD)
   - [ ] Authelia
   - [ ] Monitoring (Victoria Metrics + Grafana)
   - [ ] Loki + Promtail
   - [ ] External-DNS
   - [ ] Cloudflared
   - [ ] Homepage
   - [ ] Garage (S3 object storage)
   - [ ] Velero (backup)

5. **Post-Deployment**
   - [ ] Switch to letsencrypt-prod certificates
   - [ ] Verify all ingress routes accessible
   - [ ] Check monitoring/logging pipelines
   - [ ] Test backup/restore with Velero
   - [ ] Configure Garage buckets for Loki/Velero

---

## Migration Notes: MinIO → Garage

### Why Garage?
- Lighter weight S3-compatible storage
- Better suited for single-node/small clusters
- Built-in distributed capabilities for future expansion

### Garage Configuration
- **S3 API Port:** 3900
- **Web Interface Port:** 3902
- **Admin API Port:** 3903
- **RPC Port:** 3901 (headless service)
- **Storage:** 50Gi data + 1Gi metadata on Longhorn

### Secrets Required
- `garage-credentials`: Contains S3 access key and secret key
- `garage-tls`: TLS certificate for HTTPS access

### IngressRoutes
- `garage-s3`: S3 API endpoint
- `garage-web`: Web interface

---

## End of Snapshot

This document captures the state of the homelab cluster as of 2025-12-18.
All configuration files are stored in Git and secrets in `config/secrets.yml`.
