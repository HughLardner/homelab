# Secrets Management with Sealed Secrets

This document explains how to manage secrets in this homelab infrastructure using Bitnami Sealed Secrets for GitOps workflows.

## Overview

This project uses **Sealed Secrets** to encrypt Kubernetes secrets that can be safely committed to Git. The workflow is:

1. Store plain secrets in `secrets.yml` (gitignored, never committed)
2. Run `make seal-secrets` to encrypt them with kubeseal
3. Sealed secrets are saved to `kubernetes/` directories and committed to Git
4. ArgoCD or kubectl applies the sealed secrets to the cluster
5. The sealed-secrets controller automatically decrypts them

## Quick Start

### 1. Create Your Secrets File

```bash
# Copy the template
cp secrets.example.yml secrets.yml

# Edit with your actual secret values
vim secrets.yml
```

### 2. Seal and Commit Secrets

```bash
# Encrypt secrets and commit to git
make seal-secrets

# The playbook will:
# - Validate secrets.yml format
# - Encrypt each secret with kubeseal
# - Save sealed secrets to kubernetes/ directories
# - Git add and commit the sealed secrets
```

### 3. Apply Secrets to Cluster

```bash
# Via ArgoCD (automatic sync)
kubectl apply -f kubernetes/applications/monitoring/application.yaml

# Or manually
kubectl apply -f kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
```

## Secrets File Format

The `secrets.yml` file uses this structure:

```yaml
secrets:
  - name: secret-name          # Kubernetes secret name
    namespace: default         # Target namespace
    type: Opaque              # Secret type (Opaque, kubernetes.io/tls, etc.)
    scope: strict             # Encryption scope (strict, namespace-wide, cluster-wide)
    output_path: kubernetes/applications/myapp/secrets/secret-sealed.yaml
    data:
      key1: value1            # Secret data (key-value pairs)
      key2: value2
```

### Secret Types

**Opaque** (most common):
```yaml
- name: my-credentials
  namespace: default
  type: Opaque
  scope: strict
  output_path: kubernetes/applications/myapp/secrets/creds-sealed.yaml
  data:
    username: admin
    password: changeme
    api-key: sk_test_12345
```

**TLS Certificate**:
```yaml
- name: my-tls-cert
  namespace: default
  type: kubernetes.io/tls
  scope: strict
  output_path: kubernetes/applications/myapp/secrets/tls-sealed.yaml
  data:
    tls.crt: |
      -----BEGIN CERTIFICATE-----
      ... certificate content ...
      -----END CERTIFICATE-----
    tls.key: |
      -----BEGIN PRIVATE KEY-----
      ... private key content ...
      -----END PRIVATE KEY-----
```

**Docker Registry**:
```yaml
- name: docker-registry
  namespace: default
  type: kubernetes.io/dockerconfigjson
  scope: strict
  output_path: kubernetes/applications/myapp/secrets/registry-sealed.yaml
  data:
    .dockerconfigjson: |
      {
        "auths": {
          "ghcr.io": {
            "username": "myuser",
            "password": "ghp_token",
            "email": "user@example.com"
          }
        }
      }
```

### Encryption Scopes

**strict** (default, most secure):
- Bound to specific secret name and namespace
- Cannot rename or move to different namespace
- Recommended for production

**namespace-wide**:
- Can be renamed within the same namespace
- Cannot move to different namespace
- Useful for templated secrets

**cluster-wide**:
- Can be used anywhere in the cluster
- Least secure, use sparingly
- Useful for cluster-wide credentials

## Workflow Examples

### Adding a New Secret

1. Edit `secrets.yml`:
```yaml
secrets:
  - name: new-api-key
    namespace: default
    type: Opaque
    scope: strict
    output_path: kubernetes/applications/myapp/secrets/api-key-sealed.yaml
    data:
      api-key: sk_live_12345
```

2. Seal and commit:
```bash
make seal-secrets
# Output: kubernetes/applications/myapp/secrets/api-key-sealed.yaml created
```

3. Verify in Git:
```bash
git status
# Output: modified: kubernetes/applications/myapp/secrets/api-key-sealed.yaml
```

4. Push to remote:
```bash
git push
```

5. ArgoCD will automatically sync and apply the sealed secret

### Updating an Existing Secret

1. Edit the secret value in `secrets.yml`
2. Run `make seal-secrets` - the sealed secret will be regenerated
3. Commit and push - ArgoCD will sync the update

### Rotating a Secret

```bash
# 1. Update the value in secrets.yml
vim secrets.yml

# 2. Regenerate sealed secret
make seal-secrets

# 3. Commit to git
git add kubernetes/
git commit -m "Rotate API key"
git push

# 4. ArgoCD syncs automatically, or force sync:
kubectl -n argocd patch app monitoring --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# 5. Verify the secret was updated
kubectl get secret api-key -n default -o jsonpath='{.data.api-key}' | base64 -d
```

## Makefile Commands

```bash
# Install sealed-secrets controller
make sealed-secrets-install

# Check status
make sealed-secrets-status

# Seal secrets from secrets.yml
make seal-secrets

# View help
make help
```

## Directory Structure

```
homelab/
├── secrets.yml                    # Your plain secrets (GITIGNORED!)
├── secrets.example.yml            # Template (committed to git)
├── SECRETS.md                     # This file
├── kubernetes/
│   └── applications/
│       └── monitoring/
│           └── secrets/
│               ├── README.md
│               └── grafana-admin-sealed.yaml  # Encrypted, safe for git
└── ansible/
    └── playbooks/
        ├── seal-secrets.yml       # Main playbook
        └── seal-secret-task.yml   # Secret processing tasks
```

## Security Best Practices

### ✅ DO

- ✅ Keep `secrets.yml` in `.gitignore`
- ✅ Commit sealed secrets to git (they're encrypted)
- ✅ Use `strict` scope unless you have a specific reason
- ✅ Backup the sealed-secrets encryption key (see below)
- ✅ Rotate secrets regularly
- ✅ Use strong passwords and API keys

### ❌ DON'T

- ❌ Commit `secrets.yml` to git
- ❌ Share `secrets.yml` via email/Slack
- ❌ Use weak passwords "because they're encrypted"
- ❌ Manually edit sealed secret files (they'll be overwritten)
- ❌ Commit the sealed-secrets private key to git

## Backup and Recovery

### Backup Encryption Key

**CRITICAL**: Backup the sealed-secrets encryption key securely!

```bash
# Export the key
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-key-backup.yaml

# Store in a SECURE location:
# - Password manager (1Password, LastPass, etc.)
# - Encrypted backup storage
# - Vault (HashiCorp Vault)
# - Hardware security module (HSM)

# DO NOT store in git!
```

### Restore Encryption Key

If you rebuild your cluster, restore the key **before** installing sealed-secrets:

```bash
# 1. Apply the backed-up key
kubectl apply -f sealed-secrets-key-backup.yaml

# 2. Install sealed-secrets controller
make sealed-secrets-install

# 3. Verify decryption works
kubectl apply -f kubernetes/applications/monitoring/secrets/grafana-admin-sealed.yaml
kubectl get secret grafana-admin-secret -n monitoring
```

### Disaster Recovery

If you lose the encryption key:

1. **You cannot decrypt existing sealed secrets**
2. You must:
   - Recreate all secrets from `secrets.yml` (if you have it)
   - Or manually recreate secrets and seal them again
   - Update all sealed secrets in git

This is why backing up the encryption key is **CRITICAL**!

## Troubleshooting

### "secrets.yml not found"

```bash
# Create from template
cp secrets.example.yml secrets.yml
vim secrets.yml
```

### "kubeseal command not found"

```bash
# macOS
brew install kubeseal

# Linux - see kubernetes/services/sealed-secrets/README.md
```

### "cannot get sealed secret service"

```bash
# Ensure sealed-secrets controller is running
make sealed-secrets-status

# Install if not present
make sealed-secrets-install
```

### Secret not decrypting

```bash
# Check sealed-secrets controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check SealedSecret status
kubectl describe sealedsecret <name> -n <namespace>

# Common causes:
# - Secret was sealed with wrong encryption key
# - Encryption key was rotated
# - Scope mismatch (sealed with strict but trying to use in different namespace)
```

### Regenerating a sealed secret

If a sealed secret is corrupted or needs regeneration:

```bash
# 1. Delete the sealed secret file
rm kubernetes/applications/myapp/secrets/broken-sealed.yaml

# 2. Ensure the secret is still in secrets.yml
vim secrets.yml

# 3. Regenerate
make seal-secrets

# 4. Commit
git add kubernetes/
git commit -m "Regenerate sealed secret"
```

## Advanced Usage

### Custom Git Commit Message

```bash
ansible-playbook ansible/playbooks/seal-secrets.yml \
  -e git_commit_message="Update database credentials"
```

### Auto-push to Remote

```bash
ansible-playbook ansible/playbooks/seal-secrets.yml \
  -e git_auto_push=true
```

### Seal Single Secret

Edit `secrets.yml` to contain only the secrets you want to seal, then run `make seal-secrets`.

### Using Different Scopes

```yaml
# Strict - most secure, default
- name: prod-db-creds
  scope: strict

# Namespace-wide - can rename within namespace
- name: shared-api-key
  scope: namespace-wide

# Cluster-wide - can use anywhere (use sparingly!)
- name: cluster-wide-registry
  scope: cluster-wide
```

## Integration with ArgoCD

Sealed secrets work seamlessly with ArgoCD:

1. Sealed secrets are committed to git
2. ArgoCD detects changes and syncs automatically
3. Sealed-secrets controller decrypts them
4. Your pods can use the decrypted secrets

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    path: kubernetes/applications/myapp
    # This includes secrets/ directory with sealed secrets
```

## References

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Installation](kubernetes/services/sealed-secrets/README.md)
- [secrets.example.yml](secrets.example.yml) - Template file
- [Makefile](Makefile) - Available commands
