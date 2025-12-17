# NetworkPolicies - Namespace Isolation

NetworkPolicies provide network-level security by controlling traffic flow between pods.

## Policies Applied

| Namespace | Policy | Allows From |
|-----------|--------|-------------|
| monitoring | default-deny-ingress | traefik, monitoring |
| authelia | default-deny-ingress | traefik |
| minio | default-deny-ingress | traefik, velero |
| loki | default-deny-ingress | monitoring (Grafana), loki (Promtail) |

## How It Works

1. **Default Deny**: All ingress traffic is denied by default
2. **Explicit Allow**: Only specified traffic is allowed
3. **Same Namespace**: Pods can always communicate within their namespace

## Testing

```bash
# Check policies in a namespace
kubectl get networkpolicies -n monitoring

# Describe a policy
kubectl describe networkpolicy default-deny-ingress -n monitoring

# Test connectivity (should fail from random namespace)
kubectl run test --rm -it --image=busybox --restart=Never -- wget -qO- http://grafana.monitoring.svc
```

## Troubleshooting

If a service stops working after applying policies:

1. Check the policy allows the source namespace
2. Verify namespace labels: `kubectl get ns --show-labels`
3. Temporarily remove the policy to test: `kubectl delete networkpolicy <name> -n <namespace>`

