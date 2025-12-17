# MinIO - S3-Compatible Object Storage

MinIO provides S3-compatible object storage for Velero backups and other applications.

## Features

- **S3 Compatible**: Works with any S3-compatible client
- **Velero Integration**: Default bucket created for cluster backups
- **Authelia Protected**: Console requires SSO authentication
- **Persistent Storage**: Uses Longhorn for data persistence

## Access

- **Console**: https://minio-console.silverseekers.org (SSO required)
- **API**: https://minio.silverseekers.org (access key auth)

## Configuration

Credentials are managed via sealed secrets. The secret `minio-credentials` should contain:

```yaml
rootUser: admin
rootPassword: <generated-password>
```

## Buckets

| Bucket | Purpose |
|--------|---------|
| velero | Cluster backups (Velero) |

## Velero Integration

Velero is configured to use MinIO as its S3-compatible storage backend:

```yaml
configuration:
  backupStorageLocation:
    bucket: velero
    config:
      s3Url: http://minio.minio.svc:9000
      region: minio
      s3ForcePathStyle: "true"
```

