This directory is the Git-tracked source for shared Home Assistant state that is
created or edited through the UI / MCP tools instead of Helm values.

What belongs here:

- Shared dashboards that should survive PVC loss
- Shared automations that are not just experimental tweaks
- Stable person/tracker mapping decisions

What does not belong here:

- `.storage` registries
- Per-user UI preferences
- Session/auth metadata
- Recorder or trace data

## Current managed exports

Dashboards (one file per storage-mode dashboard, `<url_path>.dashboard.yaml`):

- `home-overview.dashboard.yaml` — landing "Home" dashboard (at-a-glance)
- `ground-floor.dashboard.yaml` — Kitchen/Dining, Sitting Room, Hall, Marie's Office, Downstairs Bathroom, Outside
- `first-floor.dashboard.yaml` — Bedroom, Landing, Office, Lily's Room, Alex's Room, Main Bathroom, Ensuite
- `attic-floor.dashboard.yaml` — Attic Landing, Attic, Litter Tray (url `attic-floor`)
- `heating-zones.dashboard.yaml` — all Wiser zones, hot water, moments, LTS graphs, iTRV health (url `heating-zones`)
- `energy-ev.dashboard.yaml` — myenergi Zappi + Harvi, charge controls, daily totals, live history (url `energy-ev`)
- `media-rooms.dashboard.yaml` — Sonos (Living Room + Kitchen), group controls, EQ, TTS/Assist (url `media-rooms`)
- `cameras-events.dashboard.yaml` — Nest cameras + event/logbook feed
- `scenes-automations.dashboard.yaml` — scenes, motion/door/time automations, bulk enable/disable
- `system-maintenance.dashboard.yaml` — backups, Z2M/SLZB/Wiser health, updates, batteries, printer
- `presence-network.dashboard.yaml` — presence + UniFi infrastructure health

Automations:

- `review-managed-automations.yaml` — shared automations (critical connectivity, UniFi telemetry, presence lighting)

## Retired dashboards

The following URLs were replaced by the floor + thematic layout and have been
deleted from live Home Assistant (their content has been absorbed):

- `office-dashboard` → absorbed into `first-floor` (Office section)
- `bedroom-dashboard` → absorbed into `first-floor` (Bedroom section)
- `security-sensors` → absorbed into `cameras-events` (events/history) and
  `system-maintenance` (battery watch)

## Current person/tracker mapping

- `person.hugh` -> `device_tracker.hugh_mobile`, `device_tracker.pixel_9_pro`
- `person.marie` -> `device_tracker.marie_s_a56`
- Hugh's UniFi tracker is the `Pixel-9-Pro` client with MAC suffix `d8:89`

## Refresh workflow

1. Pull the live config snapshot with `~/ha-edit.sh pull` on the K3s node.
2. Read the live dashboard/automation state from Home Assistant.
3. Update the files in this directory first.
4. Re-apply the shared state to Home Assistant via MCP tools
   (`ha_config_set_dashboard` for dashboards, `ha_config_set_automation` for
   automations).

This is intentionally a documented sync pattern, not an attempt to commit
ephemeral Home Assistant storage files directly.
