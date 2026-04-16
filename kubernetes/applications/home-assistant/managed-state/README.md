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

As of the 2026-04 heavy dashboard redesign, the sidebar collapses to six
mobile-first, pop-up driven dashboards. Each has one source-of-truth file
(`<url_path>.dashboard.yaml`).

Dashboards (storage-mode):

- `home-overview.dashboard.yaml` — landing "Home" dashboard. Mushroom chips
  header (people, weather, internet, Wiser cloud, energy, alarm counts),
  quick-action buttons, weather, front-door camera, media (Sonos), climate
  mini-graphs, live power sparkline, presence/persons, bubble-card popups for
  scenes and automation bulk enable/disable.
- `rooms-overview.dashboard.yaml` — replaces `ground-floor`, `first-floor`,
  `attic-floor`, and `media-rooms`. Mushroom hero grid of rooms keyed by HA
  area. Each tile opens a Bubble Card pop-up with auto-entities filtered by
  area (lights, climate, sensors, media) — no hand-maintained room lists.
- `heating-zones.dashboard.yaml` — all Wiser zones, hot water, moments as
  Mushroom perform-action buttons (write-only `button.*` entities rendered as
  template-buttons, not tiles), 2×4 thermostat grid, Apexcharts for 24h
  temperatures and heating demand, auto-entities for iTRVs needing attention.
- `energy-ev.dashboard.yaml` — myenergi Zappi + Harvi, charge-mode Mushroom
  buttons, Apexcharts live power flow and daily totals, device info.
- `security-network.dashboard.yaml` — replaces `cameras-events` and
  `presence-network`. Nest cameras picture-glance, security-sensor logbook,
  motion activity graphs, battery summary, SLZB / Z2M / Wiser cloud health,
  internet/platform health, security automations.
- `system-maintenance.dashboard.yaml` — auto-entities panels for updates,
  low batteries, unavailable entities, Zigbee/Wiser restart-needed, backup
  summary + run button, printer behind a Bubble Card popup.

Automations:

- `review-managed-automations.yaml` — shared automations (critical
  connectivity, UniFi telemetry, presence lighting)

## HACS / frontend card prerequisites

The redesigned dashboards rely on the following HACS frontend cards. Each is
installed into `/config/www/community/<card>/` and registered as a Lovelace
resource via `ha_config_set_dashboard_resource`:

- `bubble-card` — pop-up driven room/detail navigation
- `mushroom` — chips card, template/entity buttons, person cards
- `mini-graph-card` — compact sparklines
- `apexcharts-card` — rich multi-series history charts
- `auto-entities` — dynamic entity lists filtered by domain, area,
  device_class, regex, or state (used heavily on `rooms-overview`,
  `security-network`, and `system-maintenance`)
- `card-mod` — minor style overrides (no theme changes)
- `stack-in-card` — grouping without borders

Any dashboard refresh must verify these resources are still registered; a
missing resource is the most common cause of "Custom element not found".

## Retired dashboards

The following URLs were retired during the 2026-04 redesign and have been
deleted from live Home Assistant. Their content was absorbed as follows:

- `ground-floor`, `first-floor`, `attic-floor`, `media-rooms` → `rooms-overview`
  (area-driven pop-ups)
- `cameras-events`, `presence-network` → `security-network`
- `scenes-automations` → absorbed into `home-overview` bubble-card pop-ups
  (`#scenes`, `#automations`)
- `office-dashboard`, `bedroom-dashboard`, `security-sensors` → retired in
  earlier cleanup; see Git history

## Current person/tracker mapping

- `person.hugh` → `device_tracker.hugh_mobile`, `device_tracker.hugh_tablet`
- `person.marie` → `device_tracker.work_phone`

UniFi is not currently providing device_trackers (integration inactive); the
`security-network` dashboard reflects this and falls back to Wi-Fi/Zigbee
counts from MQTT/Z2M.

## Refresh workflow

1. Pull the live config snapshot with `~/ha-edit.sh pull` on the K3s node.
2. Read the live dashboard/automation state from Home Assistant.
3. Update the files in this directory first (YAML is source of truth).
4. Re-apply the shared state to Home Assistant via MCP tools
   (`ha_config_set_dashboard` for dashboards, `ha_config_set_automation` for
   automations).

This is intentionally a documented sync pattern, not an attempt to commit
ephemeral Home Assistant storage files directly.
