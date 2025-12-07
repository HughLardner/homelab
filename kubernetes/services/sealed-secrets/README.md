# Sealed Secrets

**Purpose**: Encrypt Kubernetes secrets for safe storage in Git repositories

**Status**: 🔲 Not yet deployed

**Repository**: [bitnami-labs/sealed-secrets](https://github.com/bitnami-labs/sealed-secrets)

---

## Overview

Sealed Secrets provides a solution to the "how do I store secrets in Git?" problem for GitOps workflows. It consists of:

1. **Controller**: Runs in your cluster and decrypts SealedSecrets into regular Secrets
2. **kubeseal CLI**: Encrypts plain Secrets into SealedSecrets using the controller's public key

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Developer creates plain Secret                           │
│    kubectl create secret generic mysecret --dry-run=client  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. kubeseal encrypts it (using controller's public key)     │
│    kubeseal -o yaml < secret.yaml > sealedsecret.yaml       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. SealedSecret is safe to commit to Git                    │
│    git add sealedsecret.yaml && git commit                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Controller decrypts SealedSecret into Secret             │
│    kubectl apply -f sealedsecret.yaml                       │
│    → Creates plain Secret that pods can use                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

- K3s cluster running
- kubectl access configured

### Install Controller

```bash
# Via Ansible (recommended)
make sealed-secrets-install

# Or manually via Helm
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --values kubernetes/services/sealed-secrets/values.yaml
```

### Install kubeseal CLI

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
# Download latest release
KUBESEAL_VERSION='0.26.0'
wget "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
```

**Verify Installation:**
```bash
kubeseal --version
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

---

## Usage

### Basic Workflow

#### 1. Create a Plain Secret (DO NOT APPLY)

```bash
# Create secret manifest (don't apply it!)
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=changeme \
  --namespace=default \
  --dry-run=client \
  -o yaml > secret.yaml
```

#### 2. Seal the Secret

```bash
# Encrypt the secret
kubeseal -f secret.yaml -o yaml > sealedsecret.yaml

# Clean up plain secret file
rm secret.yaml
```

#### 3. Commit to Git

```bash
# The sealed secret is safe to commit
git add sealedsecret.yaml
git commit -m "Add my-secret sealed secret"
git push
```

#### 4. Apply via kubectl or ArgoCD

```bash
# Apply manually
kubectl apply -f sealedsecret.yaml

# Or let ArgoCD sync it automatically
```

The controller will automatically decrypt it into a regular Secret that your pods can use.

---

## Common Use Cases

### Example: Database Credentials

```bash
# 1. Create the secret
kubectl create secret generic postgres-creds \
  --from-literal=username=postgres \
  --from-literal=password='MyS3cur3P@ssw0rd!' \
  --from-literal=database=myapp \
  --namespace=default \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > kubernetes/apps/myapp/postgres-creds-sealed.yaml

# 2. Commit to git
git add kubernetes/apps/myapp/postgres-creds-sealed.yaml
git commit -m "Add postgres credentials"

# 3. Apply
kubectl apply -f kubernetes/apps/myapp/postgres-creds-sealed.yaml
```

### Example: TLS Certificate

```bash
# 1. Create TLS secret from files
kubectl create secret tls my-tls-cert \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  --namespace=default \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > my-tls-cert-sealed.yaml

# 2. Commit and apply
git add my-tls-cert-sealed.yaml
git commit -m "Add TLS certificate"
kubectl apply -f my-tls-cert-sealed.yaml
```

### Example: Docker Registry Credentials

```bash
# 1. Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=myuser \
  --docker-password=ghp_mytoken \
  --docker-email=user@example.com \
  --namespace=default \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > regcred-sealed.yaml

# 2. Commit and apply
git add regcred-sealed.yaml
git commit -m "Add registry credentials"
```

---

## Scopes

Sealed Secrets supports different encryption scopes:

### Strict (default)
Secret is tied to specific name and namespace:
```bash
kubeseal --scope strict -f secret.yaml -o yaml > sealed.yaml
```
✅ Most secure
❌ Cannot rename or move to different namespace

### Namespace-wide
Secret can be used by any name in the same namespace:
```bash
kubeseal --scope namespace-wide -f secret.yaml -o yaml > sealed.yaml
```
✅ Can rename secret
❌ Cannot move to different namespace

### Cluster-wide
Secret can be used anywhere in the cluster:
```bash
kubeseal --scope cluster-wide -f secret.yaml -o yaml > sealed.yaml
```
✅ Most flexible
❌ Less secure

---

## Rotation and Key Management

### Backup Encryption Keys

**IMPORTANT**: Back up your sealing keys! If you lose them, you cannot decrypt your secrets.

```bash
# Export the sealing key
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-key-backup.yaml

# Store in a SECURE location (NOT in git!)
# - Password manager
# - Vault
# - Encrypted backup storage
```

### Restore Encryption Keys

```bash
# Apply the backed-up key before installing sealed-secrets
kubectl apply -f sealed-secrets-key-backup.yaml

# Then install sealed-secrets controller
make sealed-secrets-install
```

### Key Rotation

The controller automatically rotates keys every 30 days (configurable). Old keys are kept to decrypt existing secrets.

```bash
# View all sealing keys
kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key

# Force key rotation (if needed)
kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

---

## Advanced Usage

### Seal from stdin

```bash
echo -n 'my-secret-value' | kubectl create secret generic my-secret \
  --from-file=password=/dev/stdin \
  --dry-run=client -o yaml \
  | kubeseal -o yaml > sealed.yaml
```

### Use specific controller

```bash
# If running multiple clusters
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -f secret.yaml -o yaml
```

### Fetch public key for offline sealing

```bash
# Fetch the public key
kubeseal --fetch-cert > pub-cert.pem

# Seal offline (useful for CI/CD)
kubeseal --cert pub-cert.pem -f secret.yaml -o yaml
```

---

## Integration with Monitoring

After Prometheus is operational, enable metrics:

```yaml
# In values.yaml
metrics:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      release: kube-prometheus-stack
```

---

## Troubleshooting

### Secret Not Decrypting

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check SealedSecret status
kubectl get sealedsecret <name> -o yaml
kubectl describe sealedsecret <name>

# Verify Secret was created
kubectl get secret <name>
```

### Common Issues

**Issue**: `error: cannot get sealed secret service`
```bash
# Solution: Verify controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
kubectl get svc -n kube-system sealed-secrets-controller
```

**Issue**: `cannot unseal: no key could decrypt secret`
```bash
# Solution: The secret was sealed with a different key
# Re-seal with current key or restore the original key
kubeseal --fetch-cert  # Get current certificate
# Re-seal the secret with the new certificate
```

**Issue**: Secret created but pods can't access
```bash
# Solution: Check RBAC permissions
kubectl auth can-i get secrets --as=system:serviceaccount:default:myapp

# Check secret exists in correct namespace
kubectl get secret -n <namespace>
```

---

## Security Best Practices

1. **Never commit plain secrets**: Always seal before committing
2. **Backup sealing keys**: Store securely outside the cluster
3. **Use strict scope**: Unless you have a specific reason for wider scopes
4. **Rotate keys regularly**: Controller does this automatically every 30 days
5. **Audit access**: Review who can access sealed-secrets controller
6. **Monitor**: Enable Prometheus metrics when available

---

## Migration from Plain Secrets

To migrate existing secrets to sealed secrets:

```bash
# 1. Export existing secret
kubectl get secret my-secret -o yaml > secret.yaml

# 2. Remove runtime fields
yq eval 'del(.metadata.creationTimestamp, .metadata.resourceVersion, .metadata.uid)' secret.yaml > secret-clean.yaml

# 3. Seal it
kubeseal -f secret-clean.yaml -o yaml > my-secret-sealed.yaml

# 4. Delete original secret
kubectl delete secret my-secret

# 5. Apply sealed secret
kubectl apply -f my-secret-sealed.yaml

# 6. Clean up
rm secret.yaml secret-clean.yaml

# 7. Commit sealed secret
git add my-secret-sealed.yaml
git commit -m "Migrate my-secret to sealed secret"
```

---

## Examples in This Repository

See `kubernetes/applications/monitoring/secrets/` for examples of sealed secrets used by the monitoring stack.

---

## References

- [Official Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Helm Chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)
- [Best Practices Guide](https://github.com/bitnami-labs/sealed-secrets#secret-rotation)
