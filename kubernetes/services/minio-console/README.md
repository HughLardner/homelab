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

## Architecture

- Connects to Garage's S3 API endpoint via user-configured credentials
- Exposed via Traefik with Authelia SSO protection
- Uses S3 access keys for authentication to Garage

## Access

| Endpoint     | URL                       | Auth         |
| ------------ | ------------------------- | ------------ |
| Filestash UI | `s3-ui.silverseekers.org` | Authelia SSO |

## First-Time Setup

After deployment, you'll need to configure Filestash:

1. Access `https://s3-ui.silverseekers.org`
2. Complete the admin setup wizard
3. Configure an S3 backend with Garage credentials

### S3 Backend Configuration

When configuring the S3 connection in Filestash:

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

## Security Notes

- Authelia provides SSO protection for the web UI
- S3 access keys are entered by users in the Filestash UI
- Consider creating read-only keys for browsing vs read-write for management
