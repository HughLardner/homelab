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
- **Admin API**: Port 3903 - metrics and bucket/key management (internal only)
- **RPC**: Port 3901 - for clustering (unused in single-node)

## Access

| Endpoint | URL | Auth |
|----------|-----|------|
| S3 API | `s3.silverseekers.org` | S3 access keys |
| Internal S3 | `garage.garage.svc:3900` | S3 access keys |
| Grafana Dashboard | `grafana.silverseekers.org/d/garage` | Authelia SSO |

## Monitoring

Garage exposes Prometheus metrics on the admin port (3903). These are scraped by
VictoriaMetrics via ServiceMonitor and displayed in the official Grafana dashboard.

Dashboard panels include:
- Disk I/O (read/write bytes)
- S3 API requests by endpoint
- S3 bandwidth (bytes sent/received)
- Total bucket size and object count
- Resync queue length and errors

See: https://garagehq.deuxfleurs.fr/documentation/cookbook/monitoring/

## Secrets Required

Create `garage-credentials` secret with:
- `rpc-secret`: Random 32-byte hex string for RPC encryption
- `admin-token`: Random token for Admin API authentication

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
# List buckets
kubectl exec -n garage garage-0 -- garage bucket list

# List keys
kubectl exec -n garage garage-0 -- garage key list

# Create a new key
kubectl exec -n garage garage-0 -- garage key create mykey

# Grant bucket access
kubectl exec -n garage garage-0 -- garage bucket allow mybucket --read --write --key mykey
```

## Resources

- [Garage Documentation](https://garagehq.deuxfleurs.fr/documentation/)
- [Garage GitHub](https://git.deuxfleurs.fr/Deuxfleurs/garage)
- [S3 Compatibility](https://garagehq.deuxfleurs.fr/documentation/connect/apps/)
- [Monitoring Guide](https://garagehq.deuxfleurs.fr/documentation/cookbook/monitoring/)
