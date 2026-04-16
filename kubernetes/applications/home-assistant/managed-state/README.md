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

As of the 2026-04 heavy dashboard redesign (v2), the sidebar has seven
mobile-first dashboards. Each has one source-of-truth file
(`<url_path>.dashboard.yaml`).

**Bubble Card pop-up architecture:** v1 placed pop-ups in individual sections,
which caused them to render inline (defect). In v2 every pop-up for a
dashboard is grouped into a single top-level `type: vertical-stack` card, with
the pop-up definition (`card_type: pop-up`, `hash: "#..."`) as the first child
and its content following. This is the only reliable way to get modal overlay
rendering on mobile and desktop.

Dashboards (storage-mode):

- `home-overview.dashboard.yaml` — landing "Home" dashboard. Mushroom chips
  header (people with availability gate, alerts, quick scenes), Simple Weather
  hero, Power Flow Card Plus live grid/solar/battery/load, climate mini-graphs,
  Sonos media quick-chips, person tiles gated on availability. Single
  vertical-stack with `#scenes` and `#automations` Bubble Card pop-ups.
- `rooms-overview.dashboard.yaml` — replaces `ground-floor`, `first-floor`,
  `attic-floor`, and `media-rooms`. Streamline-Card templated room tiles
  (Mushroom template-cards with vertical layout so labels survive on mobile).
  Each area opens a Bubble Card pop-up with mini-climate-card + auto-entities
  filtered by area. AMS sensors live only in the attic pop-up (deduped).
- `heating-zones.dashboard.yaml` — Wiser zones as a mini-climate-card grid,
  scheduler-card for hot water and presets, Tabbed-Card grouping Temperatures
  / Demand / Schedule Apexcharts. iTRV/RoomStat telemetry no longer duplicated
  here — moved to `entity-health`.
- `energy-ev.dashboard.yaml` — Power Flow Card Plus hero (replaces the v1
  mini-graph live sparkline), Mushroom chips for Zappi charge-mode quick
  switches, Tabbed-Card for charge limit / lock / session settings, Apexcharts
  daily totals. Harvi CTs and myenergi hardware info moved to `entity-health`.
- `security-network.dashboard.yaml` — replaces `cameras-events` and
  `presence-network`. Nest camera picture-glance tiles (rewired to
  `camera.front_door`, `camera.back_garden`, `camera.side_gate`), logbook-card
  from HACS for motion + chime events, motion activity Apexcharts, person and
  device tiles gated on availability. Sensor batteries and SLZB coordinator
  health moved to `entity-health`.
- `system-maintenance.dashboard.yaml` — scope narrowed to backups, update
  entities (container install — only HACS + integration `update.*` entities
  exist, no `update.home_assistant_core_update`), unavailable entities list,
  and printer status (Bubble Card pop-up inside the single vertical-stack).
  Zigbee / Wiser / hardware health moved to `entity-health`.
- `entity-health.dashboard.yaml` — **new in v2.** Dedicated device/telemetry
  dashboard consolidating everything that used to be duplicated across
  heating, energy, security, and system. Bar-card battery visualisations,
  Wiser iTRV + RoomStat battery and signal entities, Zigbee mesh (SLZB
  coordinator + Z2M bridge), Wiser HeatHub + myenergi hardware, last-seen
  timestamps for devices exposing `last_seen`.

Automations:

- `review-managed-automations.yaml` — shared automations (critical
  connectivity, UniFi telemetry, presence lighting)

## HACS / frontend card prerequisites

All custom cards are **HACS-managed** (installed via `ha_hacs_download` /
HACS UI, not hand-downloaded into `/config/www/`). HACS installs them into
`/config/www/community/<card>/` and registers the matching Lovelace resource
with a `?hacstag=<hash>` cache-buster. This means upgrades happen inside HACS
with no manual file shuffling. All fifteen cards in the two lists below must
be installed and enabled before the v2 dashboards will render.

**v1 base set (converted to HACS-managed during the v2 refactor):**

- `bubble-card` — pop-up driven navigation (see pop-up architecture note above)
- `mushroom` — chips card, template/entity buttons, person cards
- `mini-graph-card` — compact sparklines
- `apexcharts-card` — rich multi-series history charts
- `auto-entities` — dynamic entity lists filtered by domain / area /
  device_class / regex / state
- `card-mod` — minor style overrides (no theme changes)
- `stack-in-card` — grouping without borders

**v2 additions (eight new HACS cards):**

- `power-flow-card-plus` — live grid / solar / battery / load flow hero used
  on `home-overview` and `energy-ev` (replaces v1 mini-graph power sparkline)
- `bar-card` — battery and health bar visualisations on `entity-health`
- `scheduler-card` — hot-water and heating-preset scheduling on
  `heating-zones`
- `streamline-card` — room-tile templating on `rooms-overview` to remove
  per-room copy-paste
- `tabbed-card` — tab grouping on `heating-zones` (Temperatures / Demand /
  Schedule) and `energy-ev` (Charge limit / Lock / Session)
- `simple-weather-card` — weather hero on `home-overview`
- `logbook-card` — motion and chime event log on `security-network`
  (replaces the stock logbook card)
- `mini-climate-card` — compact climate tiles used in room pop-ups and on
  `heating-zones`

Any dashboard refresh must verify these resources are still registered in
HACS and in `lovelace_resources`; a missing resource is still the most common
cause of "Custom element not found".

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

v2 also moved the following out of thematic dashboards into the dedicated
`entity-health` dashboard to stop duplication:

- iTRV / RoomStat batteries + signal (was on `heating-zones`)
- Harvi CTs and myenergi hardware (was on `energy-ev`)
- Sensor battery summary + SLZB coordinator (was on `security-network`)
- Zigbee / Wiser / HeatHub health panels (was on `system-maintenance`)

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
