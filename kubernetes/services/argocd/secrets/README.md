# ArgoCD Secrets

This directory contains sealed secrets for ArgoCD.

## Required Secrets

### `argocd-oidc-secret` (for SSO)

Used for Authentik OIDC integration. Contains the client secret that ArgoCD
uses to authenticate with Authentik.

| Key                           | Purpose                           |
| ----------------------------- | --------------------------------- |
| `oidc.authentik.clientSecret` | OIDC client secret from Authentik |

## Setup

1. Generate the client secret:

   ```bash
   openssl rand -hex 32
   ```

2. Add to `secrets.yml`:

   ```yaml
   - name: argocd-oidc-secret
     namespace: argocd
     type: Opaque
     scope: strict
     output_path: kubernetes/services/argocd/secrets/argocd-oidc-sealed.yaml
     data:
       oidc.authentik.clientSecret: "your-generated-secret"
   ```

   **Important**: The value must match `oidc-argocd-secret` in `authentik-secrets`.

3. Seal the secrets:

   ```bash
   make seal-secrets
   ```

## How It Works

1. The secret value is stored in Authentik (via blueprints) and ArgoCD (via this sealed secret)
2. When a user logs in via SSO, ArgoCD uses this secret to verify the OAuth token
3. Group memberships from Authentik are mapped to ArgoCD roles (see `values.yaml`)

## Group Mappings

| Authentik Group   | ArgoCD Role   |
| ----------------- | ------------- |
| ArgoCD Admins     | role:admin    |
| ArgoCD Developers | role:readonly |

## Troubleshooting

```bash
# Check if secret exists
kubectl get secret argocd-oidc-secret -n argocd

# Check ArgoCD OIDC config
kubectl get cm argocd-cm -n argocd -o yaml | grep oidc

# Check ArgoCD server logs for OIDC errors
kubectl logs -n argocd -l app.kubernetes.io/component=server | grep -i oidc
```
