# Drift Audit Runbook

Use this runbook to compare the live cluster against the repo's desired state without changing anything first.

## Goal

Detect:

- unhealthy or unsynced ArgoCD applications
- non-running pods that are not expected jobs
- infra drift between live cluster sizing and `config/homelab.yaml`
- application behavior drift caused by manual patches, failed hooks, or mutable fields

## Command Set

Run these from the repo root:

```bash
kubectl get nodes -o wide
kubectl describe node homelab-node-0 | rg "Capacity|Allocatable|cpu|memory" -A6 -B1
kubectl get ns
kubectl get svc -A | rg "LoadBalancer|NAMESPACE"
kubectl get applications.argoproj.io -A
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get deploy,statefulset -A
git rev-parse HEAD
```

If ArgoCD shows non-green apps, drill in with:

```bash
kubectl -n argocd get application <app-name> -o yaml
kubectl -n <namespace> get deploy,pods -o wide
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> logs <pod-or-deploy> --previous
```

## What "Good" Looks Like

- `kubectl get applications.argoproj.io -A` is all `Synced` and `Healthy`
- `kubectl get pods -A --field-selector=status.phase!=Running` only shows expected `Completed` jobs
- `kubectl get svc -A` shows:
  - `traefik` on `192.168.10.150`
  - `argocd-server` on `192.168.10.151`
  - `longhorn-frontend` on `192.168.10.144`
  - `pihole-dns` on `192.168.10.152`
- live namespaces match the documented application inventory

## Common Drift Patterns

### App is `OutOfSync` but `Healthy`

Usually one of:

- Helm rendered a field Kubernetes strips or normalizes
- a hook resource failed and remained behind
- a deployment replica count was changed manually
- ArgoCD `Application` objects were patched live but not committed to repo

Checks:

```bash
kubectl -n argocd get application <app-name> -o yaml
kubectl -n <namespace> get deploy <name> -o yaml
```

### App is `Degraded`

Usually one of:

- rollout deadline exceeded
- init container deadlock
- external dependency reachable at TCP level but failing protocol handshake
- bad secret material

Checks:

```bash
kubectl -n <namespace> describe deploy <name>
kubectl -n <namespace> describe pod <pod-name>
kubectl -n <namespace> logs <pod-or-deploy> --previous
```

### OTBR (device-hosted on SLZB): endpoint/drift checks

Typical signature:

- Home Assistant Thread integration cannot find or use OTBR
- Matter-over-Thread commissioning fails despite Matter server being healthy

Interpretation:

- OTBR now runs directly on SLZB; do not debug in-cluster OTBR pods
- failures are usually endpoint reachability, device mode, or HA integration config drift

Checks:

```bash
curl -sS http://192.168.40.185:8080/node/state
kubectl -n home-assistant get pods
kubectl -n home-automation get pods -l app.kubernetes.io/name=matter-server
```

If the SLZB OTBR endpoint is healthy but HA still fails, re-check HA Thread/OpenThread Border Router integration target URL.

### Repo says one thing, live infra says another

Example:

- `config/homelab.yaml` targets 14GB RAM
- live node still reports ~12GB allocatable memory

That indicates infra drift which needs Terraform / VM reconciliation rather than a Kubernetes-only fix.

## Escalation Rules

- If only generated `Secret` resources differ but `SealedSecret` does not, fix the source secret and reseal it.
- If ArgoCD keeps reverting a live fix, the repo changes have not been committed / pushed yet.
- If TCP connectivity works but protocol initialization times out, treat it as an external dependency or device-mode issue until proven otherwise.

## After Any Fix

Re-run:

```bash
kubectl get applications.argoproj.io -A
kubectl get pods -A --field-selector=status.phase!=Running
```

If the cluster is still not fully green, capture the new state in a dated `CLUSTER_STATE_SNAPSHOT_YYYY-MM-DD.md`.
