# MinIO Console Secrets

This directory contains sealed secrets for MinIO Console.

## Required Secrets

### minio-console-credentials

Contains the JWT encryption credentials:

| Key | Description | Generation |
|-----|-------------|------------|
| `pbkdf-passphrase` | Passphrase for JWT encryption | `openssl rand -base64 32` |
| `pbkdf-salt` | Salt for JWT encryption | `openssl rand -base64 32` |

## Generating Sealed Secrets

Secrets are defined in `config/secrets.yml` and sealed using the Ansible playbook:

```bash
# Generate/update sealed secrets
cd ansible
ansible-playbook playbooks/seal-secrets.yml
```

This will create `minio-console-credentials-sealed.yaml` in this directory.

## Manual Secret Creation (Development/Testing)

If you need to create secrets manually without sealing:

```bash
# Create minio-console-credentials
kubectl create secret generic minio-console-credentials \
  --namespace=minio-console \
  --from-literal=pbkdf-passphrase=$(openssl rand -base64 32) \
  --from-literal=pbkdf-salt=$(openssl rand -base64 32)
```

## Login Credentials

To log in to the console, you'll need S3 access keys from Garage:

```bash
# List all keys
kubectl exec -n garage garage-0 -- garage key list

# Get key details (shows access key and secret key)
kubectl exec -n garage garage-0 -- garage key info <key_id>

# Or create a new key for console access
kubectl exec -n garage garage-0 -- garage key create console-user
```

## Security Notes

- The console authenticates to Garage using S3 access keys
- Authelia provides SSO protection for the web UI
- PBKDF credentials are only for encrypting session JWTs

