# Garage Secrets

This directory contains sealed secrets for Garage object storage.

## Required Secrets

### garage-credentials

Contains the admin token and RPC secret for Garage:

| Key | Description | Generation |
|-----|-------------|------------|
| `rpc-secret` | 32-byte hex string for RPC encryption | `openssl rand -hex 32` |
| `admin-token` | Admin API authentication token | `openssl rand -base64 32` |

## Generating Sealed Secrets

Secrets are defined in `config/secrets.yml` and sealed using the Ansible playbook:

```bash
# Generate/update sealed secrets
cd ansible
ansible-playbook playbooks/seal-secrets.yml
```

This will create `garage-credentials-sealed.yaml` in this directory.

## Velero Integration

After Garage is deployed, the init job creates access keys for Velero.
Check the job logs for the generated credentials:

```bash
kubectl logs -n garage job/garage-init
```

Then update the `velero-credentials` secret in `config/secrets.yml` and re-seal:

```bash
ansible-playbook playbooks/seal-secrets.yml
```

## Manual Secret Creation (Development/Testing)

If you need to create secrets manually without sealing:

```bash
# Create garage-credentials
kubectl create secret generic garage-credentials \
  --namespace=garage \
  --from-literal=rpc-secret=$(openssl rand -hex 32) \
  --from-literal=admin-token=$(openssl rand -base64 32)

# Create velero-credentials (after getting keys from garage-init job)
kubectl create secret generic velero-credentials \
  --namespace=velero \
  --from-literal=cloud="[default]
aws_access_key_id=YOUR_ACCESS_KEY
aws_secret_access_key=YOUR_SECRET_KEY"
```

## Security Notes

- The `admin-token` grants full access to bucket/key management - keep it secure
- Access keys for S3 API are created dynamically by the init job
- All secrets should be sealed before committing to git

