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
kubectl get pdb -A
kubectl get events -A --sort-by=.lastTimestamp | rg "FailedScheduling|unschedulable|Evict|Drain" -i
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

### Large `Pending` wave after a reboot window

Typical signature:

- many pods across unrelated namespaces are stuck in `Pending`
- scheduler events say `node(s) were unschedulable`
- the single node is `Ready` but also `SchedulingDisabled`

Checks:

```bash
kubectl get nodes -o wide
kubectl describe node homelab-node-0 | rg "Unschedulable|Taints|Ready" -A3 -B2
kubectl get events -A --sort-by=.lastTimestamp | rg "FailedScheduling|unschedulable|Preemption" -i
kubectl get pdb -A
kubectl -n kube-system logs -l app.kubernetes.io/name=kured --since=24h
```

Interpretation:

- if events only mention `node(s) were unschedulable`, the problem is usually a stuck cordon/drain rather than CPU or memory exhaustion
- on this single-node cluster, check for blocking PDBs and Longhorn drain behavior before changing workload requests
- if kured started a reboot but the node stayed cordoned, verify the node was uncordoned after boot and inspect the recent kured drain logs

### OTBR (device-hosted on SLZB): endpoint/drift checks

Typical signature:

- Home Assistant Thread integration cannot find or use OTBR
- Matter-over-Thread commissioning fails despite Matter server being healthy

Interpretation:

- OTBR now runs in-cluster under ArgoCD; the SLZB provides the RCP radio over TCP
- failures are usually OTBR app drift, RCP reachability, or HA integration config drift

Checks:

```bash
curl -sS http://otbr.home-automation.svc:8081/node/state
kubectl -n home-assistant get pods
kubectl -n argocd get application otbr
kubectl -n home-automation get pods -l app.kubernetes.io/name=otbr
kubectl -n home-automation get pods -l app.kubernetes.io/name=matter-server
```

If the OTBR service is healthy but HA still fails, re-check HA Thread/OpenThread Border Router integration target URL and the SLZB RCP path.

#### Same-LAN checks (HA and SLZB both on Homelab VLAN)

Use this when HA shows "No border routers were found" even though OTBR API responds.

Topology in this homelab:
- HA node/pod path on `192.168.10.0/24` (Homelab VLAN)
- SLZB RCP on `192.168.10.185:6638` in `192.168.10.0/24` (Homelab VLAN)

Current live findings:
- OTBR API is healthy and returns a valid border-agent ID.
- HA has `matter`, `otbr`, and `thread` config entries pointing at the expected OTBR endpoint.
- The `Guest` VLAN is not part of the active pairing path.
- A phone on `Homelab` remains the preferred onboarding path for credential sync and pairing.

Network checks (in order):
1. **Address groups**
   - `net_homelab = 192.168.10.0/24`
   - `host_slzb_rcp = 192.168.10.185`
   - `host_ha = <HA IP on homelab>`
2. **Firewall order and isolation**
   - Inspect `LAN IN`, `LAN LOCAL`, and `GUEST` rules.
   - Ensure no same-LAN client isolation or ACL blocks node/OTBR -> SLZB RCP traffic.
3. **Minimum allow rules**
   - Allow `cluster node / OTBR pod -> host_slzb_rcp` TCP `6638`.
   - Allow `HA pod -> otbr.home-automation.svc` TCP `8081`.
4. **Discovery and onboarding**
   - Keep the phone on the `Homelab` SSID/LAN for `Sync Thread Credentials`.
   - Verify guest isolation is not enabled on the pairing SSID.
   - Verify IPv6 is enabled on the `Homelab` LAN used for Thread/Matter onboarding.

Verification after each network change:

```bash
curl -sS http://otbr.home-automation.svc:8081/node/state
curl -sS http://otbr.home-automation.svc:8081/node/ba-id
kubectl -n home-assistant exec home-assistant-0 -- \
  curl -sS http://otbr.home-automation.svc:8081/node/state
kubectl -n home-assistant exec home-assistant-0 -- \
  python3 -c "import json;from pathlib import Path;obj=json.loads(Path('/config/.storage/core.config_entries').read_text());[print(e['domain'],e.get('data')) for e in obj['data']['entries'] if e.get('domain') in {'matter','otbr','thread'}]"
```

Expected:
- OTBR state returns `"leader"`
- `ba-id` returns a non-empty ID
- HA config entries show OTBR URL `http://otbr.home-automation.svc:8081`
- Thread integration no longer reports "No border routers were found"
- Home Assistant companion app can complete `Sync Thread Credentials` from the trusted HA LAN

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
kubectl get nodes -o wide
kubectl get applications.argoproj.io -A
kubectl get pods -A --field-selector=status.phase!=Running
kubectl get events -A --sort-by=.lastTimestamp | rg "FailedScheduling|unschedulable|Evict|Drain" -i
```

If the cluster is still not fully green, capture the new state in a dated `CLUSTER_STATE_SNAPSHOT_YYYY-MM-DD.md`.
