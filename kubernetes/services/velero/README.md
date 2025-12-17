# Velero - Kubernetes Backup and Restore

Velero provides backup and restore capabilities for Kubernetes clusters.

## Features

- **Scheduled Backups**: Daily backups at 2 AM UTC
- **14-Day Retention**: Automatic cleanup of old backups
- **S3 Storage**: Uses MinIO for backup storage
- **Volume Snapshots**: Longhorn CSI snapshots included

## Backup Schedule

| Schedule | Time | Retention |
|----------|------|-----------|
| daily-backup | 2:00 AM UTC | 14 days |

## Excluded Namespaces

- kube-system
- kube-public
- kube-node-lease
- velero

## Commands

### List Backups

```bash
velero backup get
```

### Create Manual Backup

```bash
velero backup create manual-backup-$(date +%Y%m%d)
```

### Restore from Backup

```bash
velero restore create --from-backup <backup-name>
```

### Check Backup Status

```bash
velero backup describe <backup-name>
```

## Configuration

Velero credentials for MinIO are stored in sealed secret `velero-credentials`:

```yaml
cloud: |
  [default]
  aws_access_key_id=<minio-root-user>
  aws_secret_access_key=<minio-root-password>
```

## Disaster Recovery

1. **Install Velero** on new cluster with same MinIO credentials
2. **List available backups**: `velero backup get`
3. **Restore**: `velero restore create --from-backup <latest-backup>`

