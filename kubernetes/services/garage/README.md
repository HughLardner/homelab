# Garage Object Storage

Garage is an S3-compatible distributed object storage solution. This deployment provides
backup storage for Velero and potentially other S3-compatible applications.

## Why Garage over MinIO?

- **AGPL-3.0 License**: Strong copyleft prevents commercial feature stripping
- **Designed for homelabs**: Low resource footprint (~100-256MB RAM)
- **Community-driven**: Deuxfleurs collective, not venture-backed
- **No commercial pressure**: Unlike MinIO which removed OIDC/LDAP from open-source

## Architecture

Single-node standalone deployment:
- **S3 API**: Port 3900 - for Velero and other S3 clients
- **Web UI**: Port 3902 - simple file browser (exposed via Traefik + Authelia)
- **Admin API**: Port 3903 - for bucket/key management (internal only)
- **RPC**: Port 3901 - for clustering (unused in single-node)

## Access

| Endpoint | URL | Auth |
|----------|-----|------|
| S3 API | `s3.silverseekers.org` | S3 access keys |
| Web UI | `garage.silverseekers.org` | Authelia SSO |
| Internal S3 | `garage.garage.svc:3900` | S3 access keys |

## Secrets Required

Create `garage-credentials` secret with:
- `rpc-secret`: Random 32-byte hex string for RPC encryption
- `admin-token`: Random token for Admin API authentication
- `velero-access-key`: S3 access key ID for Velero
- `velero-secret-key`: S3 secret access key for Velero

Generate secrets:
```bash
# RPC Secret (32 bytes hex)
openssl rand -hex 32

# Admin Token
openssl rand -base64 32
```

## Initial Setup

After first deployment, the init job will:
1. Configure node layout (assign storage capacity)
2. Create the `velero` bucket
3. Create access keys for Velero

Check the init job logs for the generated access keys:
```bash
kubectl logs -n garage job/garage-init
```

## Velero Configuration

Velero uses these settings to connect:
```yaml
backupStorageLocation:
  config:
    s3Url: http://garage.garage.svc:3900
    region: garage
    s3ForcePathStyle: "true"
```

## Manual Bucket Management

```bash
# Port-forward admin API
kubectl port-forward -n garage svc/garage-admin 3903:3903

# List buckets
curl -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:3903/v1/bucket

# Create bucket
curl -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"globalAlias": "mybucket"}' \
  http://localhost:3903/v1/bucket
```

## Resources

- [Garage Documentation](https://garagehq.deuxfleurs.fr/documentation/)
- [Garage GitHub](https://git.deuxfleurs.fr/Deuxfleurs/garage)
- [S3 Compatibility](https://garagehq.deuxfleurs.fr/documentation/connect/apps/)

