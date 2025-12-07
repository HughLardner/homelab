# ArgoCD GitOps Platform

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Overview

This deployment includes:
- ArgoCD Server (Web UI and API)
- ArgoCD Controller (Sync controller)
- ArgoCD Repo Server (Git repository interaction)
- ArgoCD ApplicationSet Controller (Multi-cluster support)
- Redis (Caching layer)
- TLS via cert-manager and Traefik IngressRoute

## Quick Start

```bash
# Install ArgoCD
make argocd-install

# Check status
make argocd-status

# Get admin password
make argocd-password

# Open web UI
make argocd-ui
```

## Accessing the Web UI

After installation, access ArgoCD at:
- URL: `https://<argocd_domain>`
- Username: `admin`
- Password: Run `make argocd-password` to retrieve

## CLI Access

Install the ArgoCD CLI:
```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

Login via CLI:
```bash
# Login using the admin password
argocd login <argocd_domain> --username admin --password <password>

# Or login with SSO (if configured)
argocd login <argocd_domain> --sso
```

## Creating Applications

### Via Web UI

1. Log in to ArgoCD web UI
2. Click "+ NEW APP"
3. Fill in application details:
   - Application Name
   - Project: default
   - Sync Policy: Manual or Automatic
   - Repository URL: Your Git repo
   - Path: Path to manifests
   - Cluster: https://kubernetes.default.svc
   - Namespace: Target namespace

### Via CLI

```bash
argocd app create my-app \
  --repo https://github.com/your-org/your-repo.git \
  --path kubernetes/manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-namespace
```

### Via Declarative YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: HEAD
    path: kubernetes/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Configuration

### Terraform Variables

```hcl
argocd_domain   = "argocd.example.com"
argocd_password = "your-secure-password"
```

### Ansible Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_namespace` | `argocd` | Kubernetes namespace |
| `argocd_domain` | Required | Domain for ArgoCD UI |
| `argocd_password` | Required | Admin password |
| `argocd_replicas` | `1` | Server replicas |
| `argocd_cert_issuer` | `letsencrypt-staging` | Cert-manager issuer |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ArgoCD Namespace                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   Server     │    │  Controller  │    │   Repo Server    │  │
│  │  (Web UI)    │    │   (Sync)     │    │   (Git Ops)      │  │
│  └──────┬───────┘    └──────┬───────┘    └────────┬─────────┘  │
│         │                   │                     │             │
│         └───────────────────┼─────────────────────┘             │
│                             │                                   │
│                      ┌──────┴──────┐                            │
│                      │    Redis    │                            │
│                      │   (Cache)   │                            │
│                      └─────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │    Traefik IngressRoute       │
              │    (TLS Termination)          │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │      MetalLB LoadBalancer     │
              └───────────────────────────────┘
                              │
                              ▼
                    External Access
                https://argocd.example.com
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n argocd
```

### View Server Logs
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### View Controller Logs
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Reset Admin Password
```bash
# Generate bcrypt hash
htpasswd -nbBC 10 "" "newpassword" | tr -d ':\n' | sed 's/$2y/$2a/'

# Update secret
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "<bcrypt-hash>",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
```

### Check Application Sync Status
```bash
argocd app list
argocd app get my-app
```

## Security Considerations

1. **Change Default Password**: Always change the admin password after installation
2. **Use RBAC**: Configure RBAC policies for multi-user environments
3. **Enable SSO**: Consider enabling SSO for production environments
4. **Network Policies**: Apply network policies to restrict access
5. **Audit Logging**: Enable audit logging for compliance

## Related Documentation

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [GitOps Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
