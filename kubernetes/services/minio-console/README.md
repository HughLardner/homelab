# Filestash - S3 Browser UI

Filestash provides a web UI for browsing and managing S3-compatible storage.
This deployment connects to Garage as the backend storage.

> **Note**: This directory is named `minio-console` for historical reasons.
> The MinIO Console was deprecated and integrated into MinIO server in 2023.
> We use Filestash instead as it works with any S3-compatible storage.

## Why Filestash?

- **S3-compatible**: Works with any S3-compatible storage (Garage, MinIO, AWS S3, etc.)
- **AGPL-3.0 License**: Open source, copyleft license
- **Feature-rich**: Browse, upload, download, share files with a modern UI
- **Multi-backend**: Supports S3, FTP, SFTP, WebDAV, and more

## Declarative Configuration

This deployment is fully declarative:

- **Admin password**: Pre-configured via sealed secret (skips setup wizard)
- **Config**: Pre-loaded via ConfigMap
- **SSO**: Protected by Authelia forward auth

No manual UI setup required.

## Architecture

- Connects to Garage's S3 API endpoint via user-configured credentials
- Exposed via Traefik with Authelia SSO protection
- Uses S3 access keys for authentication to Garage

## Access

| Endpoint     | URL                       | Auth         |
| ------------ | ------------------------- | ------------ |
| Filestash UI | `s3-ui.silverseekers.org` | Authelia SSO |

## First-Time Admin Access

Admin password is the same as other homelab services. Access the admin panel at:
`https://s3-ui.silverseekers.org/admin`

### S3 Backend Configuration

Configure an S3 connection in the Filestash admin panel:

| Setting    | Value                           |
| ---------- | ------------------------------- |
| Endpoint   | `http://garage.garage.svc:3900` |
| Region     | `garage`                        |
| Access Key | Your Garage access key          |
| Secret Key | Your Garage secret key          |
| Path Style | `true` (required for Garage)    |

## Getting Garage Access Keys

```bash
# List all keys
kubectl exec -n garage garage-0 -- garage key list

# Get key details (shows access key and secret key)
kubectl exec -n garage garage-0 -- garage key info <key_id>

# Or create a new key for Filestash access
kubectl exec -n garage garage-0 -- garage key create filestash-user

# Grant access to buckets
kubectl exec -n garage garage-0 -- garage bucket allow velero --read --write --key filestash-user
```

## Secrets Required

### filestash-credentials

| Key                   | Description                     |
| --------------------- | ------------------------------- |
| `admin-password-hash` | bcrypt hash of admin password   |

Generated via `config/secrets.yml` and sealed with Ansible playbook.

## Security Notes

- Authelia provides SSO protection for the web UI
- S3 access keys are entered by users in the Filestash admin UI
- Consider creating read-only keys for browsing vs read-write for management
