# Resource Policies - LimitRange and ResourceQuota

Resource policies ensure fair resource allocation and prevent runaway pods.

## LimitRange

Sets default and maximum resource limits per container.

| Namespace | Default CPU | Default Memory | Max CPU | Max Memory |
|-----------|-------------|----------------|---------|------------|
| default | 200m | 256Mi | 2 | 2Gi |
| monitoring | 500m | 512Mi | 2 | 4Gi |
| loki | 500m | 512Mi | 1 | 1Gi |

## ResourceQuota

Limits total resources per namespace.

| Namespace | CPU Requests | Memory Requests | Max Pods |
|-----------|--------------|-----------------|----------|
| default | 2 | 4Gi | 20 |
| monitoring | 4 | 8Gi | 30 |
| loki | 2 | 4Gi | 10 |

## Viewing Current Usage

```bash
# Check quota usage
kubectl describe resourcequota namespace-quota -n monitoring

# Check limit ranges
kubectl describe limitrange default-limits -n default
```

## Troubleshooting

If pods fail to schedule:

1. Check quota: `kubectl describe resourcequota -n <namespace>`
2. Check events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
3. Adjust limits in the templates if needed

