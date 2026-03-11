# Headlamp Kubernetes UI

Headlamp is deployed as a cluster dashboard at `https://headlamp.silverseekers.org`.

## Authentication architecture

```
User → Authelia (SSO login) → Traefik → Headlamp → K8s API (ServiceAccount)
```

- **Authelia** gates who can reach Headlamp (forward-auth middleware on the IngressRoute).
- **Headlamp** auto-authenticates to the cluster using its ServiceAccount token — no token prompt in the UI.
- The ServiceAccount has `cluster-admin`, so anyone who passes Authelia gets full cluster access.

## How it works

Headlamp normally runs with `-in-cluster` and prompts the user for a token. To skip that prompt:

1. A **ConfigMap** (`headlamp-kubeconfig`) contains a kubeconfig that uses `tokenFile` to reference the pod's mounted SA token at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
2. The kubeconfig is mounted at `/kubeconfig/config` and passed via `-kubeconfig`.
3. `config.inCluster` is set to `false` so the `-in-cluster` flag is not added.

The `tokenFile` field means the kubelet-refreshed SA token is always used — no stale copies.

## Changing access level

To restrict what Headlamp can do, change `clusterRoleBinding.clusterRoleName` in the ArgoCD Application from `cluster-admin` to a more limited ClusterRole.
