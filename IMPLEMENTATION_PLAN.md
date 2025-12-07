# Kubernetes Services Implementation Plan

**Goal**: Deploy core platform services (Longhorn, Cert-Manager, Traefik, ArgoCD) to enable application deployments.

**Strategy**: Layered bootstrap approach - critical services via Ansible, additional services via ArgoCD.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Service Deployment Order](#service-deployment-order)
3. [Prerequisites](#prerequisites)
4. [Phase 1: Storage Layer](#phase-1-storage-layer-longhorn)
5. [Phase 2: Certificate Management](#phase-2-certificate-management-cert-manager)
6. [Phase 3: Ingress Controller](#phase-3-ingress-controller-traefik)
7. [Phase 4: GitOps Platform](#phase-4-gitops-platform-argocd)
8. [Phase 5: Monitoring Stack](#phase-5-monitoring-stack-prometheus--grafana)
9. [Testing & Validation](#testing--validation)
10. [Rollback Procedures](#rollback-procedures)
11. [Timeline Estimate](#timeline-estimate)

---

## Architecture Overview

### Deployment Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 0: Infrastructure (Terraform)                              │
│  ✅ Proxmox VMs, Networks, Storage, Firewall                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Platform (Ansible)                                      │
│  ✅ K3s Cluster (HA etcd)                                        │
│  ✅ KubeVIP (192.168.10.15)                                      │
│  ✅ MetalLB (192.168.10.150-159)                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: Core Services (Ansible) - THIS IMPLEMENTATION          │
│  🔲 Longhorn (Distributed Storage)                              │
│  🔲 Cert-Manager (TLS Certificates)                             │
│  🔲 Traefik (Ingress Controller)                                │
│  🔲 ArgoCD (GitOps Platform)                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: Platform Services (ArgoCD)                             │
│  🔲 Prometheus + Grafana (Monitoring)                           │
│  🔲 Traefik Dashboard                                           │
│  🔲 Traefik Middlewares                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Layer 4: Applications (ArgoCD)                                  │
│  🔲 Your Applications                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Order?

| Service | Why First? | Why Ansible? |
|---------|-----------|--------------|
| **Longhorn** | Storage required for stateful services | Foundation for ArgoCD persistence |
| **Cert-Manager** | TLS foundation for all HTTPS services | Required before Traefik ingress |
| **Traefik** | Ingress required for ArgoCD UI | Core networking component |
| **ArgoCD** | Bootstrap tool for remaining services | Last Ansible deployment |

---

## Service Deployment Order

### Critical Path (Ansible)

1. **Longhorn** → Storage layer
2. **Cert-Manager** → TLS foundation
3. **Traefik** → Ingress controller
4. **ArgoCD** → GitOps platform

### Non-Critical (ArgoCD)

5. **Prometheus + Grafana** → Monitoring
6. **Traefik Dashboard** → Ingress visualization
7. **Traefik Middlewares** → Advanced routing

---

## Prerequisites

### Current State (Verified ✅)

- ✅ Terraform infrastructure deployed
- ✅ K3s cluster running (3 control plane nodes)
- ✅ MetalLB installed (192.168.10.150-159)
- ✅ KubeVIP configured (192.168.10.15)
- ✅ kubectl access configured

### Required Before Starting

- [ ] Storage disks available on nodes (configured via Terraform/node-prep)
- [ ] Cloudflare domain available (for Let's Encrypt DNS validation)
- [ ] Cloudflare API token (for cert-manager DNS challenge)
- [ ] Git repository access (for ArgoCD)

### Validation Commands

```bash
# Verify K3s cluster
kubectl get nodes
kubectl get pods -A

# Verify MetalLB
kubectl get ipaddresspool -n metallb-system

# Check storage on nodes
ssh ubuntu@192.168.10.20 "df -h"
```

---

## Phase 1: Storage Layer (Longhorn)

**Purpose**: Distributed block storage for persistent volumes

**Duration**: 1-2 hours

### 1.1 Create Kubernetes Manifests

**Directory**: `kubernetes/services/longhorn/`

**Files to create**:

```
kubernetes/services/longhorn/
├── README.md                  # Documentation
├── values.yaml                # Helm values (templated)
├── kustomization.yaml         # Kustomize config
└── storageclass.yaml          # Default StorageClass
```

**values.yaml** (with Jinja2 templating):
```yaml
---
# Longhorn Helm Values
# Templated by Ansible - Single Source of Truth

defaultSettings:
  defaultReplicaCount: {{ longhorn_replica_count | default(2) }}
  defaultDataPath: {{ longhorn_data_path | default('/var/lib/longhorn') }}

persistence:
  defaultClass: true
  defaultFsType: ext4
  defaultClassReplicaCount: {{ longhorn_replica_count | default(2) }}

service:
  ui:
    type: {{ longhorn_ui_service_type | default('ClusterIP') }}
    # For LoadBalancer access during setup
    # type: LoadBalancer

ingress:
  enabled: false
  # Enable via ArgoCD later with proper TLS

resources:
  limits:
    cpu: 200m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**README.md**: Full documentation (see metallb pattern)

### 1.2 Create Ansible Playbook

**File**: `ansible/playbooks/longhorn.yml`

```yaml
---
# Longhorn Storage Installation Playbook
# Installs Longhorn distributed block storage using Helm

- name: Install Longhorn Storage
  hosts: k3s_masters[0]
  become: true
  gather_facts: true

  vars:
    longhorn_version: "1.6.0"
    longhorn_namespace: "longhorn-system"
    longhorn_replica_count: 2
    longhorn_data_path: "/var/lib/longhorn"
    longhorn_ui_service_type: "LoadBalancer"  # Change to ClusterIP after Traefik

  pre_tasks:
    - name: Check if nodes have required storage
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl get nodes -o json | \
        jq -r '.items[].status.allocatable.storage'
      register: node_storage
      changed_when: false

    - name: Display storage availability
      ansible.builtin.debug:
        msg: "Node storage: {{ node_storage.stdout_lines }}"

    - name: Wait for K3s to be ready
      ansible.builtin.command: /usr/local/bin/k3s kubectl get nodes
      register: k3s_status
      changed_when: false
      retries: 10
      delay: 5
      until: k3s_status.rc == 0

  tasks:
    - name: Create Longhorn namespace
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl create namespace {{ longhorn_namespace }}
      register: namespace_result
      changed_when: "'created' in namespace_result.stdout"
      failed_when: false

    - name: Check if Longhorn is already installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n {{ longhorn_namespace }} longhorn-driver-deployer
      register: longhorn_check
      changed_when: false
      failed_when: false

    - name: Add Longhorn Helm repository
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f https://raw.githubusercontent.com/longhorn/charts/v{{ longhorn_version }}/repo-index.yaml
      when: longhorn_check.rc != 0
      register: helm_repo
      changed_when: false

    - name: Template Longhorn values
      ansible.builtin.template:
        src: ../../kubernetes/services/longhorn/values.yaml
        dest: /tmp/longhorn-values.yaml
        mode: '0644'

    - name: Install Longhorn via Helm
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v{{ longhorn_version }}/deploy/longhorn.yaml
      when: longhorn_check.rc != 0
      register: longhorn_install
      changed_when: "'created' in longhorn_install.stdout"

    - name: Wait for Longhorn manager to be ready
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl wait --namespace {{ longhorn_namespace }} --for=condition=ready pod --selector=app=longhorn-manager --timeout=600s
      register: wait_result
      changed_when: false
      retries: 3
      delay: 10
      until: wait_result.rc == 0

    - name: Apply custom StorageClass if provided
      ansible.builtin.copy:
        src: ../../kubernetes/services/longhorn/storageclass.yaml
        dest: /tmp/longhorn-storageclass.yaml
        mode: '0644'
      when: false  # Enable if custom StorageClass needed

    - name: Verify Longhorn pods are running
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get pods -n {{ longhorn_namespace }} --no-headers
      register: longhorn_status
      changed_when: false
      failed_when: "'Running' not in longhorn_status.stdout"

  post_tasks:
    - name: Get Longhorn UI service
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl get svc -n {{ longhorn_namespace }} longhorn-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
      register: longhorn_ui_ip
      changed_when: false
      when: longhorn_ui_service_type == "LoadBalancer"

    - name: Display completion message
      ansible.builtin.debug:
        msg:
          - "✅ Longhorn installation complete!"
          - ""
          - "Configuration:"
          - "  Namespace: {{ longhorn_namespace }}"
          - "  Version: {{ longhorn_version }}"
          - "  Replica Count: {{ longhorn_replica_count }}"
          - "  Data Path: {{ longhorn_data_path }}"
          - ""
          - "Access Longhorn UI:"
          - "  {% if longhorn_ui_service_type == 'LoadBalancer' %}URL: http://{{ longhorn_ui_ip.stdout }}{% else %}kubectl port-forward -n {{ longhorn_namespace }} svc/longhorn-frontend 8080:80{% endif %}"
          - ""
          - "Verify with:"
          - "  kubectl get pods -n {{ longhorn_namespace }}"
          - "  kubectl get storageclass"
          - "  kubectl get pv"
```

### 1.3 Update Makefile

Add to `Makefile`:

```makefile
longhorn-install: inventory
	@echo "Installing Longhorn storage..."
	cd ansible && ansible-playbook playbooks/longhorn.yml

longhorn-ui:
	@echo "Opening Longhorn UI..."
	@LONGHORN_IP=$$(kubectl get svc -n longhorn-system longhorn-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "Longhorn UI: http://$$LONGHORN_IP"; \
	open "http://$$LONGHORN_IP" || xdg-open "http://$$LONGHORN_IP" || echo "Open http://$$LONGHORN_IP in your browser"
```

### 1.4 Testing & Validation

```bash
# Install Longhorn
make longhorn-install

# Verify installation
kubectl get pods -n longhorn-system
kubectl get storageclass
kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | xargs -n1 kubectl describe node | grep -A5 "Allocatable:"

# Test PVC creation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc longhorn-test-pvc
kubectl delete pvc longhorn-test-pvc

# Access UI
make longhorn-ui
```

### 1.5 Expected Outcome

- ✅ Longhorn deployed to all nodes
- ✅ StorageClass `longhorn` available
- ✅ UI accessible via LoadBalancer IP
- ✅ Able to create PVCs

---

## Phase 2: Certificate Management (Cert-Manager)

**Purpose**: Automated TLS certificate issuance and renewal

**Duration**: 1-2 hours

### 2.1 Create Kubernetes Manifests

**Directory**: `kubernetes/services/cert-manager/`

**Files to create**:

```
kubernetes/services/cert-manager/
├── README.md
├── values.yaml                    # Helm values
├── kustomization.yaml
├── cluster-issuer-letsencrypt-staging.yaml
├── cluster-issuer-letsencrypt-prod.yaml
└── cluster-issuer-selfsigned.yaml
```

**values.yaml**:
```yaml
---
# Cert-Manager Helm Values

installCRDs: true

global:
  leaderElection:
    namespace: cert-manager

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 32Mi

prometheus:
  enabled: false  # Enable when Prometheus deployed
```

**cluster-issuer-letsencrypt-prod.yaml** (with templating):
```yaml
---
# Let's Encrypt Production Issuer
# Uses Cloudflare DNS challenge for wildcard certificates

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: {{ cert_manager_email }}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudflare:
          email: {{ cloudflare_email }}
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
      selector:
        dnsZones:
          - {{ cert_manager_domain }}
```

**cluster-issuer-letsencrypt-staging.yaml**: Same as prod but staging server

**cluster-issuer-selfsigned.yaml**:
```yaml
---
# Self-Signed Issuer for Internal Services

apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
```

### 2.2 Create Ansible Playbook

**File**: `ansible/playbooks/cert-manager.yml`

```yaml
---
# Cert-Manager Installation Playbook
# Installs cert-manager for automated TLS certificate management

- name: Install Cert-Manager
  hosts: k3s_masters[0]
  become: true
  gather_facts: true

  vars:
    cert_manager_version: "v1.14.0"
    cert_manager_namespace: "cert-manager"
    cert_manager_email: "{{ cert_manager_email }}"  # From inventory
    cloudflare_email: "{{ cloudflare_email }}"      # From inventory
    cloudflare_api_token: "{{ cloudflare_api_token }}"  # From inventory
    cert_manager_domain: "{{ cert_manager_domain }}"  # From inventory

  pre_tasks:
    - name: Verify required variables
      ansible.builtin.fail:
        msg: "{{ item }} is not defined in inventory"
      when: vars[item] is not defined or vars[item] == ""
      loop:
        - cert_manager_email
        - cloudflare_email
        - cloudflare_api_token
        - cert_manager_domain

  tasks:
    - name: Create cert-manager namespace
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl create namespace {{ cert_manager_namespace }}
      register: namespace_result
      changed_when: "'created' in namespace_result.stdout"
      failed_when: false

    - name: Check if cert-manager is already installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n {{ cert_manager_namespace }} cert-manager
      register: certmanager_check
      changed_when: false
      failed_when: false

    - name: Install cert-manager CRDs
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/{{ cert_manager_version }}/cert-manager.crds.yaml
      when: certmanager_check.rc != 0
      register: crds_install
      changed_when: "'created' in crds_install.stdout"

    - name: Install cert-manager
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/{{ cert_manager_version }}/cert-manager.yaml
      when: certmanager_check.rc != 0
      register: certmanager_install
      changed_when: "'created' in certmanager_install.stdout"

    - name: Wait for cert-manager webhook to be ready
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl wait --namespace {{ cert_manager_namespace }} --for=condition=ready pod --selector=app.kubernetes.io/component=webhook --timeout=300s
      register: wait_result
      changed_when: false
      retries: 3
      delay: 10
      until: wait_result.rc == 0

    - name: Create Cloudflare API token secret
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl create secret generic cloudflare-api-token \
          --from-literal=api-token={{ cloudflare_api_token }} \
          --namespace {{ cert_manager_namespace }} \
          --dry-run=client -o yaml | /usr/local/bin/k3s kubectl apply -f -
      register: secret_result
      changed_when: "'created' in secret_result.stdout or 'configured' in secret_result.stdout"

    - name: Template ClusterIssuers
      ansible.builtin.template:
        src: "{{ item }}"
        dest: "/tmp/{{ item | basename }}"
        mode: '0644'
      loop:
        - ../../kubernetes/services/cert-manager/cluster-issuer-letsencrypt-staging.yaml
        - ../../kubernetes/services/cert-manager/cluster-issuer-letsencrypt-prod.yaml
        - ../../kubernetes/services/cert-manager/cluster-issuer-selfsigned.yaml

    - name: Apply ClusterIssuers
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f /tmp/{{ item }}
      loop:
        - cluster-issuer-letsencrypt-staging.yaml
        - cluster-issuer-letsencrypt-prod.yaml
        - cluster-issuer-selfsigned.yaml
      register: issuer_result
      changed_when: "'created' in issuer_result.stdout or 'configured' in issuer_result.stdout"

    - name: Cleanup temporary files
      ansible.builtin.file:
        path: "/tmp/{{ item }}"
        state: absent
      loop:
        - cluster-issuer-letsencrypt-staging.yaml
        - cluster-issuer-letsencrypt-prod.yaml
        - cluster-issuer-selfsigned.yaml

  post_tasks:
    - name: Display completion message
      ansible.builtin.debug:
        msg:
          - "✅ Cert-Manager installation complete!"
          - ""
          - "Configuration:"
          - "  Namespace: {{ cert_manager_namespace }}"
          - "  Version: {{ cert_manager_version }}"
          - "  Domain: {{ cert_manager_domain }}"
          - ""
          - "ClusterIssuers:"
          - "  - letsencrypt-staging (for testing)"
          - "  - letsencrypt-prod (for production)"
          - "  - selfsigned (for internal services)"
          - ""
          - "Verify with:"
          - "  kubectl get pods -n {{ cert_manager_namespace }}"
          - "  kubectl get clusterissuer"
          - "  kubectl describe clusterissuer letsencrypt-prod"
```

### 2.3 Update Inventory

Add to `ansible/inventory/generate_inventory.py` and `clusters.tf`:

```python
# In generate_inventory.py
"cert_manager_email": config.get("cert_manager_email", ""),
"cert_manager_domain": config.get("cert_manager_domain", ""),
"cloudflare_email": config.get("cloudflare_email", ""),
```

Add to Terraform `clusters.tf`:
```hcl
cert_manager_email   = "your-email@domain.com"
cert_manager_domain  = "yourdomain.com"
cloudflare_email     = "your-cloudflare@domain.com"
```

**Note**: Cloudflare API token should be in `secrets.tf`:
```hcl
variable "cloudflare_api_token" {
  description = "Cloudflare API token for cert-manager DNS challenge"
  type        = string
  sensitive   = true
}
```

### 2.4 Update Makefile

```makefile
cert-manager-install: inventory
	@echo "Installing cert-manager..."
	cd ansible && ansible-playbook playbooks/cert-manager.yml
```

### 2.5 Testing & Validation

```bash
# Install cert-manager
make cert-manager-install

# Verify installation
kubectl get pods -n cert-manager
kubectl get clusterissuer

# Test certificate issuance (staging)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.yourdomain.com
EOF

# Check certificate status
kubectl describe certificate test-cert
kubectl get certificaterequest
kubectl get order
kubectl get challenge

# Cleanup
kubectl delete certificate test-cert
```

### 2.6 Expected Outcome

- ✅ Cert-manager deployed
- ✅ Three ClusterIssuers configured
- ✅ Cloudflare integration working
- ✅ Able to issue certificates

---

## Phase 3: Ingress Controller (Traefik)

**Purpose**: HTTP/HTTPS routing with TLS termination

**Duration**: 2-3 hours

### 3.1 Create Kubernetes Manifests

**Directory**: `kubernetes/services/traefik/`

**Files to create/update**:

```
kubernetes/services/traefik/
├── README.md
├── values.yaml                # Helm values (UPDATE existing)
├── kustomization.yaml
├── dashboard-ingress.yaml     # Optional: Dashboard via Ingress
└── middleware-basic-auth.yaml # Optional: Basic auth middleware
```

**values.yaml** (UPDATE existing file):
```yaml
---
# Traefik Helm Values
# Single Source of Truth for Traefik Configuration

# Additional CLI arguments
additionalArguments:
  - '--serversTransport.insecureSkipVerify=true'
  - '--log.level=INFO'
  - '--accesslog=true'
  - '--metrics.prometheus=true'

# Service configuration
service:
  enabled: true
  type: LoadBalancer
  annotations:
    metallb.universe.tf/address-pool: default-pool
  spec:
    externalTrafficPolicy: Local

# Ports configuration
ports:
  web:
    port: 80
    expose: true
    exposedPort: 80
  websecure:
    port: 443
    expose: true
    exposedPort: 443
    tls:
      enabled: true
      certResolver: letsencrypt-prod
  metrics:
    port: 9100
    expose: false

# TLS configuration
tlsOptions:
  default:
    minVersion: VersionTLS12
    cipherSuites:
      - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
      - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

# Certificate resolvers
certResolvers:
  letsencrypt-staging:
    acme:
      email: {{ cert_manager_email | default('your-email@domain.com') }}
      storage: /data/acme-staging.json
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory
      dnsChallenge:
        provider: cloudflare
  letsencrypt-prod:
    acme:
      email: {{ cert_manager_email | default('your-email@domain.com') }}
      storage: /data/acme-prod.json
      caServer: https://acme-v02.api.letsencrypt.org/directory
      dnsChallenge:
        provider: cloudflare

# Environment variables for Cloudflare
env:
  - name: CF_API_EMAIL
    valueFrom:
      secretKeyRef:
        name: cloudflare-credentials
        key: email
  - name: CF_DNS_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-credentials
        key: api-token

# Persistence for ACME certificates
persistence:
  enabled: true
  name: traefik-acme
  size: 128Mi
  storageClass: longhorn
  accessMode: ReadWriteOnce
  path: /data

# Resources
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Dashboard configuration
ingressRoute:
  dashboard:
    enabled: true
    matchRule: Host(`traefik.{{ traefik_domain | default('localhost') }}`)
    entryPoints:
      - websecure
    tls:
      certResolver: letsencrypt-prod

# Pilot dashboard (disable for privacy)
pilot:
  enabled: false

# Logs
logs:
  general:
    level: INFO
  access:
    enabled: true
```

**dashboard-ingress.yaml**:
```yaml
---
# Traefik Dashboard IngressRoute
# Access: https://traefik.yourdomain.com/dashboard/

apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`traefik.{{ traefik_domain }}`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
      middlewares:
        - name: dashboard-auth
  tls:
    certResolver: letsencrypt-prod
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth
```

### 3.2 Create Ansible Playbook

**File**: `ansible/playbooks/traefik.yml`

```yaml
---
# Traefik Ingress Controller Installation Playbook
# Installs Traefik via Helm for HTTP/HTTPS routing

- name: Install Traefik Ingress Controller
  hosts: k3s_masters[0]
  become: true
  gather_facts: true

  vars:
    traefik_version: "26.0.0"  # Helm chart version
    traefik_namespace: "traefik"
    traefik_domain: "{{ traefik_domain }}"  # From inventory
    cert_manager_email: "{{ cert_manager_email }}"
    cloudflare_email: "{{ cloudflare_email }}"
    cloudflare_api_token: "{{ cloudflare_api_token }}"
    traefik_dashboard_user: "admin"
    traefik_dashboard_password: "{{ traefik_dashboard_password | default('changeme') }}"

  pre_tasks:
    - name: Verify required variables
      ansible.builtin.fail:
        msg: "{{ item }} is not defined"
      when: vars[item] is not defined or vars[item] == ""
      loop:
        - traefik_domain
        - cert_manager_email
        - cloudflare_email
        - cloudflare_api_token

    - name: Verify cert-manager is installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n cert-manager cert-manager
      register: certmanager_check
      changed_when: false
      failed_when: certmanager_check.rc != 0

    - name: Verify Longhorn is installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get storageclass longhorn
      register: longhorn_check
      changed_when: false
      failed_when: longhorn_check.rc != 0

  tasks:
    - name: Create Traefik namespace
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl create namespace {{ traefik_namespace }}
      register: namespace_result
      changed_when: "'created' in namespace_result.stdout"
      failed_when: false

    - name: Create Cloudflare credentials secret
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl create secret generic cloudflare-credentials \
          --from-literal=email={{ cloudflare_email }} \
          --from-literal=api-token={{ cloudflare_api_token }} \
          --namespace {{ traefik_namespace }} \
          --dry-run=client -o yaml | /usr/local/bin/k3s kubectl apply -f -
      register: cf_secret_result
      changed_when: "'created' in cf_secret_result.stdout or 'configured' in cf_secret_result.stdout"

    - name: Generate dashboard password hash
      ansible.builtin.shell: |
        echo "{{ traefik_dashboard_password }}" | openssl passwd -apr1 -stdin
      register: dashboard_password_hash
      changed_when: false
      no_log: true

    - name: Create dashboard auth secret
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl create secret generic traefik-dashboard-auth \
          --from-literal=users='{{ traefik_dashboard_user }}:{{ dashboard_password_hash.stdout }}' \
          --namespace {{ traefik_namespace }} \
          --dry-run=client -o yaml | /usr/local/bin/k3s kubectl apply -f -
      register: auth_secret_result
      changed_when: "'created' in auth_secret_result.stdout or 'configured' in auth_secret_result.stdout"

    - name: Check if Traefik is already installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n {{ traefik_namespace }} traefik
      register: traefik_check
      changed_when: false
      failed_when: false

    - name: Template Traefik values
      ansible.builtin.template:
        src: ../../kubernetes/services/traefik/values.yaml
        dest: /tmp/traefik-values.yaml
        mode: '0644'

    - name: Install Traefik via Helm
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl apply -f - <<EOF
        apiVersion: v1
        kind: ServiceAccount
        metadata:
          name: traefik
          namespace: {{ traefik_namespace }}
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: traefik
        rules:
          - apiGroups: [""]
            resources: ["services", "endpoints", "secrets"]
            verbs: ["get", "list", "watch"]
          - apiGroups: ["extensions", "networking.k8s.io"]
            resources: ["ingresses", "ingressclasses"]
            verbs: ["get", "list", "watch"]
          - apiGroups: ["extensions", "networking.k8s.io"]
            resources: ["ingresses/status"]
            verbs: ["update"]
          - apiGroups: ["traefik.containo.us"]
            resources: ["*"]
            verbs: ["get", "list", "watch"]
        ---
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRoleBinding
        metadata:
          name: traefik
        roleRef:
          apiGroup: rbac.authorization.k8s.io
          kind: ClusterRole
          name: traefik
        subjects:
          - kind: ServiceAccount
            name: traefik
            namespace: {{ traefik_namespace }}
        EOF
      when: traefik_check.rc != 0
      register: rbac_result
      changed_when: "'created' in rbac_result.stdout"

    - name: Download and apply Traefik CRDs
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f https://raw.githubusercontent.com/traefik/traefik-helm-chart/v{{ traefik_version }}/traefik/crds/
      when: traefik_check.rc != 0
      register: crds_result
      changed_when: "'created' in crds_result.stdout"

    - name: Deploy Traefik
      ansible.builtin.shell: |
        /usr/local/bin/k3s helm repo add traefik https://traefik.github.io/charts || true
        /usr/local/bin/k3s helm repo update
        /usr/local/bin/k3s helm upgrade --install traefik traefik/traefik \
          --namespace {{ traefik_namespace }} \
          --version {{ traefik_version }} \
          --values /tmp/traefik-values.yaml \
          --wait --timeout 10m
      when: traefik_check.rc != 0
      register: helm_install
      changed_when: true

    - name: Wait for Traefik to be ready
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl wait --namespace {{ traefik_namespace }} --for=condition=ready pod --selector=app.kubernetes.io/name=traefik --timeout=300s
      register: wait_result
      changed_when: false
      retries: 3
      delay: 10
      until: wait_result.rc == 0

    - name: Apply dashboard IngressRoute
      ansible.builtin.template:
        src: ../../kubernetes/services/traefik/dashboard-ingress.yaml
        dest: /tmp/traefik-dashboard-ingress.yaml
        mode: '0644'
      register: dashboard_template

    - name: Create dashboard IngressRoute
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -f /tmp/traefik-dashboard-ingress.yaml
      when: dashboard_template.changed
      register: ingress_result
      changed_when: "'created' in ingress_result.stdout or 'configured' in ingress_result.stdout"

    - name: Cleanup temporary files
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop:
        - /tmp/traefik-values.yaml
        - /tmp/traefik-dashboard-ingress.yaml

  post_tasks:
    - name: Get Traefik LoadBalancer IP
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl get svc -n {{ traefik_namespace }} traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
      register: traefik_lb_ip
      changed_when: false
      retries: 30
      delay: 5
      until: traefik_lb_ip.stdout != ""

    - name: Display completion message
      ansible.builtin.debug:
        msg:
          - "✅ Traefik installation complete!"
          - ""
          - "Configuration:"
          - "  Namespace: {{ traefik_namespace }}"
          - "  Version: {{ traefik_version }}"
          - "  LoadBalancer IP: {{ traefik_lb_ip.stdout }}"
          - "  Domain: {{ traefik_domain }}"
          - ""
          - "Dashboard Access:"
          - "  URL: https://traefik.{{ traefik_domain }}/dashboard/"
          - "  Username: {{ traefik_dashboard_user }}"
          - "  Password: {{ traefik_dashboard_password }}"
          - ""
          - "DNS Configuration Required:"
          - "  Add A record: *.{{ traefik_domain }} → {{ traefik_lb_ip.stdout }}"
          - "  Or use /etc/hosts: {{ traefik_lb_ip.stdout }} traefik.{{ traefik_domain }}"
          - ""
          - "Verify with:"
          - "  kubectl get pods -n {{ traefik_namespace }}"
          - "  kubectl get svc -n {{ traefik_namespace }}"
          - "  kubectl get ingressroute -n {{ traefik_namespace }}"
          - "  curl -k https://{{ traefik_lb_ip.stdout }}"
```

### 3.3 Update Inventory & Terraform

Add to inventory and Terraform:

```python
# generate_inventory.py
"traefik_domain": config.get("traefik_domain", ""),
```

```hcl
# clusters.tf
traefik_domain = "yourdomain.com"
```

```hcl
# secrets.tf
variable "traefik_dashboard_password" {
  description = "Traefik dashboard password"
  type        = string
  sensitive   = true
  default     = "changeme"
}
```

### 3.4 Update Makefile

```makefile
traefik-install: inventory
	@echo "Installing Traefik ingress controller..."
	cd ansible && ansible-playbook playbooks/traefik.yml

traefik-dashboard:
	@echo "Opening Traefik dashboard..."
	@TRAEFIK_DOMAIN=$$(cd terraform && terraform output -json | jq -r '.cluster_config.value.traefik_domain // "localhost"'); \
	echo "Dashboard: https://traefik.$$TRAEFIK_DOMAIN/dashboard/"; \
	open "https://traefik.$$TRAEFIK_DOMAIN/dashboard/" || xdg-open "https://traefik.$$TRAEFIK_DOMAIN/dashboard/"
```

### 3.5 Testing & Validation

```bash
# Install Traefik
make traefik-install

# Verify installation
kubectl get pods -n traefik
kubectl get svc -n traefik
kubectl get ingressroute -n traefik

# Get LoadBalancer IP
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Add to /etc/hosts (temporary)
echo "192.168.10.150 traefik.yourdomain.com" | sudo tee -a /etc/hosts

# Test dashboard access
curl -k https://traefik.yourdomain.com/dashboard/
make traefik-dashboard

# Deploy test application
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: traefik/whoami
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: whoami
spec:
  selector:
    app: whoami
  ports:
  - port: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: whoami
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`whoami.yourdomain.com`)
      kind: Rule
      services:
        - name: whoami
          port: 80
  tls:
    certResolver: letsencrypt-staging  # Use staging first!
EOF

# Test ingress
curl -k https://whoami.yourdomain.com

# Check certificate
kubectl get certificate
kubectl describe certificate whoami-tls

# Cleanup
kubectl delete ingressroute whoami
kubectl delete svc whoami
kubectl delete deployment whoami
```

### 3.6 Expected Outcome

- ✅ Traefik deployed with LoadBalancer
- ✅ Dashboard accessible
- ✅ HTTPS working with Let's Encrypt
- ✅ Test application routable

---

## Phase 4: GitOps Platform (ArgoCD)

**Purpose**: Continuous deployment for remaining services

**Duration**: 2-3 hours

### 4.1 Create Kubernetes Manifests

**Directory**: `kubernetes/services/argocd/`

```
kubernetes/services/argocd/
├── README.md
├── values.yaml                # Helm values
├── kustomization.yaml
├── ingress.yaml               # ArgoCD UI ingress
└── app-of-apps.yaml           # Bootstrap remaining services
```

**values.yaml**:
```yaml
---
# ArgoCD Helm Values

global:
  domain: argocd.{{ traefik_domain | default('localhost') }}

server:
  service:
    type: LoadBalancer  # Use LoadBalancer initially, switch to Ingress later
  ingress:
    enabled: false      # Enable after testing with LoadBalancer
    ingressClassName: traefik
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      traefik.ingress.kubernetes.io/router.entrypoints: websecure
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.{{ traefik_domain }}

  config:
    url: https://argocd.{{ traefik_domain }}
    application.instanceLabelKey: argocd.argoproj.io/instance

  rbacConfig:
    policy.default: role:readonly

redis:
  enabled: true

controller:
  replicas: 1

repoServer:
  replicas: 1

applicationSet:
  enabled: true

dex:
  enabled: false  # Disable SSO for now

notifications:
  enabled: false  # Enable later for Slack/email alerts
```

**app-of-apps.yaml**:
```yaml
---
# ArgoCD App of Apps
# Bootstraps all platform services

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-services
  namespace: argocd
spec:
  project: default
  source:
    repoURL: {{ argocd_repo_url }}
    path: kubernetes/services/argocd/apps
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
```

**apps/** directory:
```
kubernetes/services/argocd/apps/
├── prometheus-stack.yaml
├── grafana.yaml
├── traefik-dashboard.yaml
└── traefik-middlewares.yaml
```

### 4.2 Create Ansible Playbook

**File**: `ansible/playbooks/argocd.yml`

```yaml
---
# ArgoCD Installation Playbook
# Installs ArgoCD for GitOps continuous deployment

- name: Install ArgoCD
  hosts: k3s_masters[0]
  become: true
  gather_facts: true

  vars:
    argocd_version: "v2.10.0"
    argocd_namespace: "argocd"
    argocd_domain: "argocd.{{ traefik_domain }}"
    argocd_repo_url: "{{ argocd_repo_url }}"  # From inventory
    traefik_domain: "{{ traefik_domain }}"

  pre_tasks:
    - name: Verify Traefik is installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n traefik traefik
      register: traefik_check
      changed_when: false
      failed_when: traefik_check.rc != 0

  tasks:
    - name: Create ArgoCD namespace
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl create namespace {{ argocd_namespace }}
      register: namespace_result
      changed_when: "'created' in namespace_result.stdout"
      failed_when: false

    - name: Check if ArgoCD is already installed
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl get deployment -n {{ argocd_namespace }} argocd-server
      register: argocd_check
      changed_when: false
      failed_when: false

    - name: Install ArgoCD
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl apply -n {{ argocd_namespace }} -f https://raw.githubusercontent.com/argoproj/argo-cd/{{ argocd_version }}/manifests/install.yaml
      when: argocd_check.rc != 0
      register: argocd_install
      changed_when: "'created' in argocd_install.stdout"

    - name: Wait for ArgoCD server to be ready
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl wait --namespace {{ argocd_namespace }} --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=600s
      register: wait_result
      changed_when: false
      retries: 3
      delay: 10
      until: wait_result.rc == 0

    - name: Patch ArgoCD server service to LoadBalancer
      ansible.builtin.command:
        cmd: /usr/local/bin/k3s kubectl patch svc argocd-server -n {{ argocd_namespace }} -p '{"spec":{"type":"LoadBalancer"}}'
      register: patch_result
      changed_when: "'patched' in patch_result.stdout"

    - name: Get ArgoCD LoadBalancer IP
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl get svc -n {{ argocd_namespace }} argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
      register: argocd_lb_ip
      changed_when: false
      retries: 30
      delay: 5
      until: argocd_lb_ip.stdout != ""

    - name: Get ArgoCD admin password
      ansible.builtin.shell: |
        /usr/local/bin/k3s kubectl -n {{ argocd_namespace }} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
      register: argocd_password
      changed_when: false
      no_log: true

  post_tasks:
    - name: Display completion message
      ansible.builtin.debug:
        msg:
          - "✅ ArgoCD installation complete!"
          - ""
          - "Configuration:"
          - "  Namespace: {{ argocd_namespace }}"
          - "  Version: {{ argocd_version }}"
          - "  LoadBalancer IP: {{ argocd_lb_ip.stdout }}"
          - ""
          - "Access ArgoCD:"
          - "  URL: https://{{ argocd_lb_ip.stdout }}"
          - "  Username: admin"
          - "  Password: {{ argocd_password.stdout }}"
          - ""
          - "Or with domain (add to /etc/hosts):"
          - "  {{ argocd_lb_ip.stdout }} {{ argocd_domain }}"
          - "  URL: https://{{ argocd_domain }}"
          - ""
          - "CLI Login:"
          - "  argocd login {{ argocd_lb_ip.stdout }} --username admin --password '{{ argocd_password.stdout }}' --insecure"
          - ""
          - "Next Steps:"
          - "  1. Login to ArgoCD UI"
          - "  2. Deploy app-of-apps for remaining services"
          - "  3. Switch to Ingress after testing"
          - ""
          - "Verify with:"
          - "  kubectl get pods -n {{ argocd_namespace }}"
          - "  kubectl get svc -n {{ argocd_namespace }}"
```

### 4.3 Update Makefile

```makefile
argocd-install: inventory
	@echo "Installing ArgoCD..."
	cd ansible && ansible-playbook playbooks/argocd.yml

argocd-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

argocd-ui:
	@echo "Opening ArgoCD UI..."
	@ARGOCD_IP=$$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "ArgoCD UI: https://$$ARGOCD_IP"; \
	echo "Username: admin"; \
	echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"; \
	open "https://$$ARGOCD_IP" || xdg-open "https://$$ARGOCD_IP"
```

### 4.4 Testing & Validation

```bash
# Install ArgoCD
make argocd-install

# Get credentials
make argocd-password

# Open UI
make argocd-ui

# Or access via kubectl port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Install ArgoCD CLI (optional)
brew install argocd  # macOS
# or
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# Login via CLI
ARGOCD_IP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login $ARGOCD_IP --username admin --password "$ARGOCD_PASSWORD" --insecure

# Add Git repository
argocd repo add https://github.com/your-org/homelab --name homelab

# Deploy test application
argocd app create test-app \
  --repo https://github.com/your-org/homelab \
  --path kubernetes/apps/test \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Sync application
argocd app sync test-app

# View applications
argocd app list
```

### 4.5 Expected Outcome

- ✅ ArgoCD deployed and accessible
- ✅ Can login to UI
- ✅ Can add Git repositories
- ✅ Ready to deploy remaining services

---

## Phase 5: Monitoring Stack (Prometheus + Grafana)

**Purpose**: Metrics collection and visualization

**Duration**: 1-2 hours

**Deployment Method**: Via ArgoCD (not Ansible)

### 5.1 Create ArgoCD Application

**File**: `kubernetes/services/argocd/apps/prometheus-stack.yaml`

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 55.5.0
    helm:
      valuesObject:
        prometheus:
          prometheusSpec:
            storageSpec:
              volumeClaimTemplate:
                spec:
                  storageClassName: longhorn
                  resources:
                    requests:
                      storage: 10Gi
        grafana:
          adminPassword: changeme
          persistence:
            enabled: true
            storageClassName: longhorn
            size: 5Gi
          ingress:
            enabled: true
            ingressClassName: traefik
            hosts:
              - grafana.yourdomain.com
            tls:
              - secretName: grafana-tls
                hosts:
                  - grafana.yourdomain.com
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 5.2 Deployment

```bash
# Apply via kubectl
kubectl apply -f kubernetes/services/argocd/apps/prometheus-stack.yaml

# Or via ArgoCD UI
# Navigate to Applications → New App → Paste YAML

# Verify
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Open: http://localhost:3000
# Username: admin
# Password: changeme
```

---

## Testing & Validation

### Service Dependency Tests

```bash
# Test 1: Storage (Longhorn)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc test-pvc
kubectl delete pvc test-pvc

# Test 2: Certificates (Cert-Manager)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - test.yourdomain.com
EOF
kubectl get certificate test-cert
kubectl describe certificate test-cert
kubectl delete certificate test-cert

# Test 3: Ingress (Traefik)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-test
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`test.yourdomain.com\`)
      kind: Rule
      services:
        - name: nginx-test
          port: 80
  tls:
    certResolver: letsencrypt-staging
EOF

curl -k https://test.yourdomain.com
kubectl delete ingressroute nginx-test
kubectl delete svc nginx-test
kubectl delete deployment nginx-test

# Test 4: ArgoCD Deployment
# Deploy via ArgoCD UI or CLI
argocd app create test-app \
  --repo https://github.com/your-org/homelab \
  --path kubernetes/apps/test \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

argocd app sync test-app
argocd app delete test-app
```

### Integration Tests

```bash
# End-to-end test: Deploy application with storage, ingress, and TLS
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: wordpress-data
          mountPath: /var/www/html
      volumes:
      - name: wordpress-data
        persistentVolumeClaim:
          claimName: wordpress-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
  namespace: test-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: test-app
spec:
  selector:
    app: wordpress
  ports:
  - port: 80
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: wordpress
  namespace: test-app
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`wordpress.yourdomain.com\`)
      kind: Rule
      services:
        - name: wordpress
          port: 80
  tls:
    certResolver: letsencrypt-staging
EOF

# Verify all components
kubectl get all -n test-app
kubectl get pvc -n test-app
kubectl get ingressroute -n test-app
kubectl get certificate -n test-app

# Access application
curl -k https://wordpress.yourdomain.com

# Cleanup
kubectl delete namespace test-app
```

---

## Rollback Procedures

### Longhorn Rollback

```bash
# Uninstall Longhorn
kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml
kubectl delete namespace longhorn-system

# Note: PVs will be orphaned - backup data first!
```

### Cert-Manager Rollback

```bash
# Delete ClusterIssuers
kubectl delete clusterissuer letsencrypt-prod letsencrypt-staging selfsigned

# Uninstall cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
kubectl delete namespace cert-manager
```

### Traefik Rollback

```bash
# Uninstall via Helm
/usr/local/bin/k3s helm uninstall traefik -n traefik
kubectl delete namespace traefik

# Or re-enable K3s bundled Traefik
# Edit ansible/roles/k3s/defaults/main.yml: k3s_disable_traefik: false
# Re-run: make k3s-install
```

### ArgoCD Rollback

```bash
# Uninstall ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
kubectl delete namespace argocd
```

---

## Timeline Estimate

| Phase | Task | Estimated Time |
|-------|------|----------------|
| **Prep** | Update Terraform variables | 30 min |
| **Prep** | Update inventory generator | 30 min |
| **Prep** | Cloudflare setup | 30 min |
| **Phase 1** | Longhorn (create manifests + playbook + test) | 2 hours |
| **Phase 2** | Cert-Manager (create manifests + playbook + test) | 2 hours |
| **Phase 3** | Traefik (create manifests + playbook + test) | 3 hours |
| **Phase 4** | ArgoCD (create manifests + playbook + test) | 2 hours |
| **Phase 5** | Prometheus/Grafana (via ArgoCD) | 1 hour |
| **Testing** | Integration testing | 2 hours |
| **Docs** | Update READMEs | 1 hour |
| **Total** | | **14-16 hours** |

**Realistic Timeline**: 2-3 days (with breaks and troubleshooting)

---

## Success Criteria

### Phase 1 Complete
- [ ] Longhorn deployed on all nodes
- [ ] StorageClass available
- [ ] Can create PVCs
- [ ] UI accessible

### Phase 2 Complete
- [ ] Cert-manager deployed
- [ ] ClusterIssuers configured
- [ ] Can issue test certificate
- [ ] Cloudflare integration working

### Phase 3 Complete
- [ ] Traefik deployed with LoadBalancer
- [ ] Dashboard accessible
- [ ] HTTPS working with Let's Encrypt
- [ ] Test application routable

### Phase 4 Complete
- [ ] ArgoCD deployed
- [ ] UI accessible
- [ ] Can deploy applications
- [ ] Git repository connected

### Phase 5 Complete
- [ ] Prometheus collecting metrics
- [ ] Grafana accessible
- [ ] Dashboards displaying data

### Final State
- [ ] All services running
- [ ] DNS configured
- [ ] Monitoring operational
- [ ] Documentation updated
- [ ] Team trained on operations

---

## Next Steps After Completion

1. **Switch ArgoCD to Ingress** (from LoadBalancer)
2. **Deploy App-of-Apps** for platform services
3. **Configure Grafana Dashboards**
4. **Set up Alerting** (Prometheus AlertManager)
5. **Deploy First Application** via ArgoCD
6. **Implement Backup Strategy** (Longhorn backups)
7. **Set up Monitoring Alerts** (Slack/Email)
8. **Document Runbooks** for operations

---

## Support & Resources

### Official Documentation
- [Longhorn](https://longhorn.io/docs/)
- [Cert-Manager](https://cert-manager.io/docs/)
- [Traefik](https://doc.traefik.io/traefik/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Prometheus](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/)

### Community Resources
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)

### Troubleshooting
See individual service READMEs in `kubernetes/services/<service>/`

---

**Plan Version**: 1.0
**Last Updated**: 2024-12-05
**Status**: Ready for Implementation
