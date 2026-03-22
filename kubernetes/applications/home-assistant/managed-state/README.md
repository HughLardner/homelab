This directory is the Git-tracked source for shared Home Assistant state that is
currently created through the UI or MCP tools instead of Helm values.

What belongs here:
- Shared dashboards that should survive PVC loss
- Shared automations that are not just experimental tweaks
- Stable person/tracker mapping decisions

What does not belong here:
- `.storage` registries
- Per-user UI preferences
- Session/auth metadata
- Recorder or trace data

Current managed exports:
- `presence-network.dashboard.yaml`
- `review-managed-automations.yaml`

Current person/tracker mapping:
- `person.hugh` -> `device_tracker.hugh_mobile`, `device_tracker.pixel_9_pro`
- `person.marie` -> `device_tracker.marie_s_a56`
- Hugh's UniFi tracker is the `Pixel-9-Pro` client with MAC suffix `d8:89`

Refresh workflow:
1. Pull the live config snapshot with `~/ha-edit.sh pull` on the K3s node.
2. Read the live dashboard/automation state from Home Assistant.
3. Update the files in this directory first.
4. Re-apply the shared state to Home Assistant via MCP tools.

This is intentionally a documented sync pattern, not an attempt to commit
ephemeral Home Assistant storage files directly.
