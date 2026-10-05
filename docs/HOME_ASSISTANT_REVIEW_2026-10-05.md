# Home Assistant Review

Date: 2026-10-05. Supersedes `HOME_ASSISTANT_REVIEW_2026-03-22.md`.

## Snapshot

- HA `2026.3.3` (Container), pod `home-assistant-0`, ~1 GiB RAM
- 1268 entities (614 disabled), 30 config entries, 23 UI automations, 15 dashboards
- `/config` PVC: 9.7 GB, 64% used. Recorder DB 5.0 GB, local backups ~1 GB.

## Findings

| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | P0 | HA backups go to `backup.local` only, on the same PVC as the data. Velero backs up manifests only (no CSI snapshot CRDs; the `aws` snapshotter can't snapshot Longhorn), and Longhorn has no backup target. Before 2026-10-04, the last successful automatic backup was 2026-04-17. | Needs UI action + Velero follow-up |
| 2 | P0 | Alertmanager posts to webhook `alertmanager-k8s`, but no automation handled it, so cluster alerts were silently dropped. | Fixed in `packages/alerting.yaml` |
| 3 | P0 | Automations in `managed-state/review-managed-automations.yaml` were never live. | Moved to `packages/` |
| 4 | P0 | The live `configuration.yaml` lacks the `homeassistant: packages:` include, so `packages/plex.yaml` never loaded and `input_boolean.plex_server` didn't exist. | Needs one-time live edit |
| 5 | P1 | A `cffi` 2.1.1 / `_cffi_backend` 2.0.0 mismatch breaks every `pycryptodome` import: the Google Calendar integration and the Roborock config flow. | Expected to clear with image upgrade |
| 6 | P1 | HA was 7 months behind and no Renovate PR had been merged. | Upgraded to `2026.9.4` (via 2026.6.4) |
| 7 | P1 | `Bedtime — Scene & Wind Down` references the missing `scene.bedroom_lamps_bed_time` every night. | Needs UI fix |
| 8 | P1 | Claude Code's MCP token for `/api/mcp` is rejected (401). | Needs new token |
| 9 | P2 | UniFi CPU/memory sensors (~2s updates) produced ~60% of recorder rows. | Excluded in `packages/core.yaml` |
| 10 | P2 | The `probes:` block in `values.yaml` was ignored (the chart reads `livenessProbe`/`startupProbe`), so the pod ran on 3 × 20s default liveness with no startup probe. The memory request was 256Mi vs ~1 GiB used. | Fixed in `values.yaml` |
| 11 | P2 | Zigbee2MQTT discovery uses the deprecated `object_id` (~20 entities). | Upgrade Z2M |
| 12 | P2 | 3 stale disabled automations; `device_id`-based triggers; two overlapping bedtime automations. | Needs UI cleanup |
| 13 | P2 | Repo drift: `-wide` dashboards missing from Git, stale READMEs, Matter Hub leftovers still deployed. | Dashboards exported, READMEs fixed; leftovers to delete |

## Follow-ups

1. Add `homeassistant: packages: !include_dir_merge_named packages` to the live `configuration.yaml`, then restart.
2. In Settings → System → Backups, add Garage S3 and Google Drive agents, store the encryption key outside the cluster, and delete the 578 MB September manual tar.
3. After the packages load, run `recorder.purge` with `repack: true`.
4. Check Renovate's Dependency Dashboard (no HA update PR was ever merged).
5. Fix the bedtime scene reference, then delete or re-enable the disabled automations, the `map` dashboard and `plotly-graph-card`.
6. Delete `kubernetes/applications/home-assistant-matter-hub/` and `home-assistant/secrets/home-assistant-matter-hub-auth-sealed.yaml`, and revoke that HA token.
7. Cluster-wide: give Velero real PV backups (Kopia file-system backup or a Longhorn backup target).
