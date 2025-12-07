# ArgoCD Applications

This directory contains ArgoCD `Application` manifests for managing cluster services via GitOps.

## Overview

We use the **App-of-Apps pattern** where a root Application manages all other Applications.

```
root-app (watches kubernetes/applications/)
  ├── monitoring/application.yaml → Deploys Prometheus + Grafana
  ├── future-app/application.yaml → Add more apps here
  └── ...
```

## Quick Start

### 1. Bootstrap ArgoCD

```bash
# Install ArgoCD itself via Ansible (one-time bootstrap)
make argocd-install
```

### 2. Deploy Root Application

```bash
# Deploy the App-of-Apps
kubectl apply -f kubernetes/applications/root-app.yaml

# Or via ArgoCD CLI
argocd app create root-app \
  --repo https://github.com/HughLardner/homelab.git \
  --path kubernetes/applications \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace argocd \
  --sync-policy automated
```

### 3. Watch ArgoCD Deploy Everything

```bash
# View all applications
argocd app list

# Watch sync status
argocd app get monitoring
argocd app get root-app

# View in UI
open https://argocd.silverseekers.org
```

## GitOps Workflow

### Making Changes

1. **Edit manifests or values in this repo**
   ```bash
   vim kubernetes/services/monitoring/values.yaml
   ```

2. **Commit and push**
   ```bash
   git add kubernetes/services/monitoring/values.yaml
   git commit -m "Update monitoring retention to 30d"
   git push
   ```

3. **ArgoCD automatically syncs** (if automated sync enabled)
   - Or manually sync: `argocd app sync monitoring`

### Adding New Applications

1. **Create Application directory and files**
   ```bash
   mkdir -p kubernetes/applications/my-app
   cd kubernetes/applications/my-app
   ```

   **Option A: Helm chart-based application**
   ```yaml
   # application.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     project: default
     sources:
       - repoURL: https://example.com/helm-charts
         targetRevision: 1.0.0
         chart: my-app
         helm:
           valueFiles:
             - $values/kubernetes/applications/my-app/values.yaml
       - repoURL: https://github.com/HughLardner/homelab.git
         targetRevision: HEAD
         ref: values
     destination:
       server: https://kubernetes.default.svc
       namespace: my-app
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

   **Option B: Plain manifests**
   ```yaml
   # application.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-app
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/HughLardner/homelab.git
       targetRevision: HEAD
       path: kubernetes/applications/my-app
     destination:
       server: https://kubernetes.default.svc
       namespace: my-app
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```

2. **Commit and push**
   ```bash
   git add kubernetes/applications/my-app/
   git commit -m "Add my-app"
   git push
   ```

3. **Root app auto-deploys new app**
   - The root-app watches `*/application.yaml` so new apps are automatically discovered

## Architecture

### Bootstrap Layer (Ansible - one-time)
- K3s
- MetalLB
- Longhorn
- cert-manager
- Traefik
- **ArgoCD itself**

### GitOps Layer (ArgoCD - continuous)
- Monitoring (Prometheus + Grafana)
- Future applications
- Configuration changes

## Application Structure

Each application follows this structure:

```
kubernetes/
└── applications/
    └── my-app/
        ├── application.yaml   # ArgoCD Application manifest
        ├── values.yaml        # Helm values (no templating!)
        ├── ingressroute.yaml  # Traefik IngressRoute
        ├── manifests.yaml     # Plain Kubernetes manifests
        ├── kustomization.yaml # Kustomize config
        └── README.md          # Application documentation
```

All application files are kept together in one directory for easier management.

## Secrets Management

This project uses **Sealed Secrets** (Bitnami) to safely store encrypted secrets in Git.

### How It Works

1. **Plain secrets** are stored in `secrets.yml` (gitignored)
2. **Encrypt with kubeseal** via `make seal-secrets`
3. **Sealed secrets** are committed to Git (safe - can only be decrypted by cluster)
4. **ArgoCD syncs** sealed secrets from Git
5. **Sealed Secrets controller** automatically decrypts them in the cluster

### Quick Start

```bash
# 1. Create your secrets file
cp secrets.example.yml secrets.yml
vim secrets.yml

# 2. Encrypt and commit
make seal-secrets

# 3. ArgoCD automatically applies them
# Or manually: kubectl apply -f kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
```

### Example Secret Definition

```yaml
# secrets.yml (never committed)
secrets:
  - name: grafana-admin-secret
    namespace: monitoring
    type: Opaque
    scope: strict
    output_path: kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
    data:
      admin-user: admin
      admin-password: your-secure-password
```

After running `make seal-secrets`, a SealedSecret file is created and committed:

```yaml
# kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml (safe to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: grafana-admin-secret
  namespace: monitoring
spec:
  encryptedData:
    admin-user: AgAFudtUn21lVQO4... (encrypted)
    admin-password: AgAYdDHviFDItIt3... (encrypted)
```

### Documentation

See [SECRETS.md](../../SECRETS.md) for comprehensive secrets management guide.

### Alternative Options (Future)

**External Secrets Operator:**
```yaml
# Reference secrets from external source
helm:
  valuesObject:
    grafana:
      adminPassword:
        valueFrom:
          secretKeyRef:
            name: grafana-admin
            key: password
```

**ArgoCD Vault Plugin:**
```yaml
# Reference from Vault
grafana_admin_password: <path:secret/data/grafana#password>
```

## Commands

```bash
# List all applications
argocd app list
kubectl get applications -n argocd

# Sync application
argocd app sync monitoring

# View application details
argocd app get monitoring

# View application diff
argocd app diff monitoring

# Rollback application
argocd app rollback monitoring

# Delete application
argocd app delete monitoring

# Refresh application (re-check git)
argocd app refresh monitoring
```

## Sync Policies

### Automated Sync
```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in git
    selfHeal: true   # Auto-sync on drift
    allowEmpty: false
```

### Manual Sync
```yaml
syncPolicy:
  # No automated section = manual sync only
  syncOptions:
    - CreateNamespace=true
```

## Troubleshooting

### Application OutOfSync

```bash
# Check what's different
argocd app diff monitoring

# View sync status
argocd app get monitoring

# Force sync
argocd app sync monitoring --force
```

### Application Not Auto-Syncing

1. Check sync policy:
   ```bash
   argocd app get monitoring -o yaml | grep -A 5 syncPolicy
   ```

2. Check repo access:
   ```bash
   argocd repo list
   ```

3. Check ArgoCD logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
   ```

### Helm Values Not Applied

If using Ansible-templated values:
1. Values must be templated before ArgoCD can use them
2. Either pre-template and commit, or use one of the secrets management solutions above

## Best Practices

1. **Always commit to git** - ArgoCD watches git, not local changes
2. **Use automated sync** - Enable selfHeal for production
3. **Test changes in staging** - Use different targetRevision for different environments
4. **Keep secrets out of git** - Use External Secrets or Sealed Secrets
5. **Use health checks** - Define custom health checks for applications
6. **Monitor sync status** - Set up alerts for sync failures

## Related Documentation

- [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
