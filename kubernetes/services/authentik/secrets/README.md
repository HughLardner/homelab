# Authentik Secrets

This directory contains sealed secrets for Authentik SSO.

## Required Secrets

The following secrets must be configured in `secrets.yml` (project root) before deployment:

### 1. authentik-secrets

Contains the main Authentik configuration secrets:

| Key                   | Description                                            |
| --------------------- | ------------------------------------------------------ |
| `secret-key`          | Cryptographic key for signing (must be 50+ characters) |
| `postgresql-password` | PostgreSQL database password                           |
| `bootstrap-password`  | Initial admin password (optional)                      |
| `bootstrap-token`     | Initial API token (optional)                           |

## Setup Instructions

1. **Copy the secrets template**:

   ```bash
   cp secrets.example.yml secrets.yml
   ```

2. **Edit `secrets.yml`** and add the Authentik section:

   ```yaml
   secrets:
     - name: authentik-secrets
       namespace: authentik
       type: Opaque
       scope: strict
       output_path: kubernetes/services/authentik/secrets/authentik-secrets-sealed.yaml
       data:
         secret-key: "your-50-character-minimum-cryptographic-secret-key-here"
         postgresql-password: "your-secure-postgresql-password"
         # Optional: uncomment for automated initial setup
         # bootstrap-password: "initial-admin-password"
         # bootstrap-token: "initial-api-token"
   ```

3. **Generate a secure secret key** (50+ characters):

   ```bash
   openssl rand -base64 50 | tr -d '\n'
   ```

4. **Seal the secrets**:

   ```bash
   make seal-secrets
   ```

5. **Commit the sealed secret**:
   ```bash
   git add kubernetes/services/authentik/secrets/authentik-secrets-sealed.yaml
   git commit -m "Add sealed secrets for Authentik SSO"
   ```

## Security Notes

- The `secrets.yml` file is gitignored and should **never** be committed
- Only sealed secrets (encrypted) should be stored in git
- The secret key is used for signing cookies, JWTs, and other security tokens
- Rotate secrets periodically by updating `secrets.yml` and re-sealing

## Verification

After deployment, verify secrets are available:

```bash
kubectl get secrets -n authentik
kubectl describe secret authentik-secrets -n authentik
```
