# MinIO Console (Object Browser)

MinIO Console provides a web UI for browsing and managing S3-compatible storage.
This deployment connects to Garage as the backend storage.

## Why MinIO Console?

- **S3-compatible**: Works with any S3-compatible storage (Garage, MinIO, etc.)
- **AGPL-3.0 License**: Open source, copyleft license
- **Feature-rich**: Browse buckets, upload/download files, manage policies

## Architecture

- Connects to Garage's S3 API endpoint internally
- Exposed via Traefik with Authelia SSO protection
- Uses S3 access keys for authentication to Garage

## Access

| Endpoint | URL | Auth |
|----------|-----|------|
| Console UI | `s3-ui.silverseekers.org` | Authelia SSO + S3 keys |

## Secrets Required

Create `minio-console-credentials` secret with:
- `pbkdf-passphrase`: Random passphrase for JWT encryption
- `pbkdf-salt`: Random salt for JWT encryption

Generate secrets:
```bash
# PBKDF Passphrase (32 bytes base64)
openssl rand -base64 32

# PBKDF Salt (32 bytes base64)
openssl rand -base64 32
```

## Login

Use the Garage S3 access keys to log in:
- Access Key: Your Garage access key ID
- Secret Key: Your Garage secret access key

To get Velero's keys (or create new ones):
```bash
kubectl exec -n garage garage-0 -- garage key list
kubectl exec -n garage garage-0 -- garage key info <key_id>
```

