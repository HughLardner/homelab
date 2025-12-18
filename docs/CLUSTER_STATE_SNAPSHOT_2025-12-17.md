# Homelab Cluster State Snapshot

**Generated:** 2025-12-17 23:49 UTC  
**Cluster Age:** 47 hours  
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
| argocd | 47h | GitOps deployment |
| authelia | 46h | Authentication portal |
| cert-manager | 47h | TLS certificate management |
| cloudflared | 22h | Cloudflare tunnel |
| default | 47h | Default namespace |
| external-dns | 21h | DNS automation |
| homepage | 9h | Dashboard |
| kube-node-lease | 47h | Node heartbeat |
| kube-public | 47h | Public resources |
| kube-system | 47h | System components |
| loki | 22h | Log aggregation |
| longhorn-system | 47h | Distributed storage |
| metallb-system | 47h | LoadBalancer |
| minio | 15h | Object storage |
| monitoring | 35h | Victoria Metrics + Grafana |
| traefik | 47h | Ingress controller |
| velero | 22h | Backup (not deployed) |

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

---

## ArgoCD Applications

| Application | Sync Status | Health | Notes |
|-------------|-------------|--------|-------|
| argocd-ingress | Synced | Healthy | ✅ |
| authelia | Synced | Healthy | ✅ |
| cert-manager | Unknown | Healthy | ⚠️ Sync status unknown |
| cloudflared | Synced | Healthy | ✅ |
| external-dns | Synced | Healthy | ✅ |
| homepage | Synced | Healthy | ✅ |
| loki | Synced | Healthy | ✅ |
| longhorn-ingress | Synced | Healthy | ✅ |
| minio | Synced | Healthy | ✅ |
| monitoring | Synced | Healthy | ✅ |
| network-policies | Synced | Healthy | ✅ |
| promtail | Synced | Healthy | ✅ |
| resource-policies | Synced | Healthy | ✅ |
| root-app | Synced | Healthy | ✅ App-of-Apps pattern |
| traefik | Synced | Healthy | ✅ |
| velero | OutOfSync | Missing | ❌ Not deploying |

---

## Pod Status Summary

### All Pods Running ✅

**Total: 54 pods (all Running)**

#### argocd (5 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| argocd-application-controller-0 | Running | 0 | 31h |
| argocd-applicationset-controller-fd979c6d4-rtdcj | Running | 0 | 32h |
| argocd-redis-64bcbd4d76-pjsp8 | Running | 0 | 32h |
| argocd-repo-server-568b666f45-vhxhs | Running | 0 | 31h |
| argocd-server-5f467677f8-rwfqt | Running | 0 | 31h |

#### authelia (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| authelia-677b48fddb-jxvxv | Running | 0 | 9h |

#### cert-manager (3 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| cert-manager-6b6fb948c9-ffzff | Running | 0 | 47h |
| cert-manager-cainjector-7b49c96b7b-v9thl | Running | 0 | 47h |
| cert-manager-webhook-6ff9d5cf4b-zbnhw | Running | 0 | 47h |

#### cloudflared (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| cloudflared-7cd6648896-l2s7l | Running | 2 (21h ago) | 21h |

#### external-dns (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| external-dns-fcd8b45f-lqlmg | Running | 0 | 15h |

#### homepage (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| homepage-79c8cdf798-7ghfq | Running | 0 | 18m |

#### kube-system (4 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| coredns-659f584bfd-dvpfc | Running | 0 | 47h |
| local-path-provisioner-774c6665dc-xq5p9 | Running | 0 | 47h |
| metrics-server-7bfffcd44-8r4wp | Running | 0 | 47h |
| sealed-secrets-controller-bd6746fd7-4z992 | Running | 0 | 47h |

#### loki (3 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| loki-0 | Running | 0 | 21h |
| loki-canary-lc9ql | Running | 0 | 22h |
| promtail-s9ld7 | Running | 0 | 15h |

#### longhorn-system (15 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| csi-attacher-58b6c6fdf6-* (3) | Running | various | 47h |
| csi-provisioner-74f57b955d-* (3) | Running | various | 47h |
| csi-resizer-6cfcbf5f5-* (3) | Running | 0 | 47h |
| csi-snapshotter-5fcb76449-* (3) | Running | 0 | 47h |
| engine-image-ei-acb7590c-kxc64 | Running | 0 | 47h |
| instance-manager-d5f89eeb3f965a8a18536620faebd2d2 | Running | 0 | 47h |
| longhorn-csi-plugin-l4955 | Running | 0 | 47h |
| longhorn-driver-deployer-7586c8d85b-z8kgz | Running | 0 | 47h |
| longhorn-manager-mlwhz | Running | 1 (47h ago) | 47h |
| longhorn-ui-77d4995f67-* (2) | Running | 0 | 47h |

#### metallb-system (2 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| controller-bb5f47665-rf627 | Running | 0 | 47h |
| speaker-xmgcb | Running | 0 | 47h |

#### minio (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| minio-59b6b9d597-4s2mc | Running | 0 | 14h |

#### monitoring (7 pods)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| grafana-5c58bf9c5b-wglt8 | Running | 0 | 22h |
| kube-state-metrics-57db796588-jzcqv | Running | 0 | 29h |
| node-exporter-prometheus-node-exporter-5jv9x | Running | 0 | 29h |
| vm-operator-victoria-metrics-operator-785b7bcd7-h52xp | Running | 0 | 29h |
| vmagent-vmagent-c4768f65d-l6mzx | Running | 26 (3m ago) | 32h |
| vmalert-vmalert-858db5945b-4d46v | Running | 0 | 32h |
| vmalertmanager-vmalertmanager-0 | Running | 0 | 32h |
| vmsingle-vmsingle-69965db646-9bsjp | Running | 0 | 32h |

#### traefik (1 pod)
| Pod | Status | Restarts | Age |
|-----|--------|----------|-----|
| traefik-6ccfbc5bbf-cqpgd | Running | 0 | 47h |

---

## Services

### LoadBalancer Services (External IPs)

| Service | Namespace | External IP | Ports |
|---------|-----------|-------------|-------|
| traefik | traefik | 192.168.10.145 | 80, 443 |
| longhorn-frontend | longhorn-system | 192.168.10.144 | 80 |

### ClusterIP Services

| Service | Namespace | Cluster IP | Ports |
|---------|-----------|------------|-------|
| argocd-server | argocd | 10.43.171.7 | 80, 443 |
| authelia | authelia | 10.43.192.175 | 80 |
| cert-manager | cert-manager | 10.43.168.185 | 9402 |
| external-dns | external-dns | 10.43.248.79 | 7979 |
| homepage | homepage | 10.43.66.31 | 3000 |
| kube-dns | kube-system | 10.43.0.10 | 53, 9153 |
| loki | loki | 10.43.91.78 | 3100, 9095 |
| grafana | monitoring | 10.43.163.176 | 80 |
| minio | minio | 10.43.51.51 | 9000 |
| minio-console | minio | 10.43.222.17 | 9001 |
| vmsingle-vmsingle | monitoring | 10.43.251.38 | 8429 |
| kube-state-metrics | monitoring | 10.43.135.182 | 8080 |

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
| storage-loki-0 | loki | longhorn | 10Gi | Bound |
| minio | minio | longhorn | 50Gi | Bound |
| grafana | monitoring | local-path | 5Gi | Bound |
| vmalertmanager-vmalertmanager-db-vmalertmanager-vmalertmanager-0 | monitoring | local-path | 1Gi | Bound |
| vmsingle-vmsingle | monitoring | local-path | 2Gi | Bound |

### Persistent Volumes
| PV | Capacity | Status | Claim | Storage Class |
|----|----------|--------|-------|---------------|
| pvc-513b8b36-d02f-49b1-8f4c-087a41f3a313 | 1Gi | Bound | authelia/authelia | longhorn |
| pvc-9f16ca19-af8c-47d6-a2d1-3e55b65479e6 | 10Gi | Bound | loki/storage-loki-0 | longhorn |
| pvc-7828399a-9257-4a11-acf2-62ef6e12de77 | 50Gi | Bound | minio/minio | longhorn |
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
| homepage-tls | homepage | letsencrypt-staging | True | homepage-tls |
| longhorn-frontend-tls | longhorn-system | letsencrypt-staging | True | longhorn-frontend-tls |
| minio-console-tls | minio | letsencrypt-staging | True | minio-console-tls |
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
| homepage | homepage | Homepage Dashboard |
| longhorn-frontend | longhorn-system | Longhorn UI |
| minio-api | minio | MinIO API |
| minio-console | minio | MinIO Console |
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
| minio | 5m | 116Mi |
| longhorn-manager | 11m | 113Mi |
| loki | 16m | 109Mi |
| homepage | 1m | 99Mi |
| grafana | 9m | 82Mi |

**Total Pod Resources:** 152m CPU, 2374Mi Memory

---

## Known Issues

### ❌ Velero Deployment Failing
- **Status:** OutOfSync, Health: Missing
- **Error:** `velero-upgrade-crds` job failing with BackoffLimitExceeded
- **Details:** CRD upgrade job container crashing repeatedly
- **Action Required:** Fix velero deployment or remove from ArgoCD apps

### ⚠️ VMAgent Restarting
- **Pod:** vmagent-vmagent-c4768f65d-l6mzx
- **Restarts:** 26 (most recent 3m ago)
- **Action Required:** Check vmagent logs for configuration issues

### ⚠️ Cert-Manager Sync Status Unknown
- **Application:** cert-manager
- **Status:** Unknown (but Health: Healthy)
- **Action Required:** May need manual sync or investigation

### ⚠️ Cloudflared Restarts
- **Pod:** cloudflared-7cd6648896-l2s7l
- **Restarts:** 2 (21h ago)
- **Status:** Currently stable

### ⚠️ Staging Certificates
- All certificates using `letsencrypt-staging`
- Not trusted by browsers
- **Action Required:** Switch to `letsencrypt-prod` after rebuild

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
| grafana-admin-secret | monitoring | Opaque | admin-user, admin-password |
| grafana-oidc-secret | monitoring | Opaque | clientSecret |
| minio-credentials | minio | Opaque | rootUser, rootPassword |
| sealed-secrets-keyb5jmm | kube-system | kubernetes.io/tls | tls.crt, tls.key |
| letsencrypt-prod-account-key | cert-manager | Opaque | tls.key |
| letsencrypt-staging-account-key | cert-manager | Opaque | tls.key |

---

## ConfigMaps Reference

### Application Configurations
| ConfigMap | Namespace | Data Keys |
|-----------|-----------|-----------|
| homepage-config | homepage | 9 config files |
| authelia | authelia | configuration.yaml |
| loki | loki | loki config |
| grafana | monitoring | grafana.ini sections |
| minio | minio | minio config |
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
   - [ ] MinIO
   - [ ] Fix Velero deployment

5. **Post-Deployment**
   - [ ] Switch to letsencrypt-prod certificates
   - [ ] Verify all ingress routes accessible
   - [ ] Check monitoring/logging pipelines
   - [ ] Test backup/restore with Velero

---

## End of Snapshot

This document captures the state of the homelab cluster as of 2025-12-17.
All configuration files are stored in Git and secrets in `config/secrets.yml`.

