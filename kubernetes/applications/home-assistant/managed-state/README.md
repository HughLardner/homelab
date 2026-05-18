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

As of the 2026-04 v3 split (mobile + wide), the sidebar has **fourteen**
dashboards: seven mobile-first originals plus seven `-wide` desktop/tablet
variants. Each has one source-of-truth file (`<url_path>.dashboard.yaml`).

**Why two sets:** `max_columns: 4` layouts densely pack a phone screen but
look sparse on desktop/tablet. The `-wide` variants all use `panel: true`
with a single top-level `vertical-stack` and `horizontal-stack`/`grid`
children to fill the full viewport width with no column-width clamping.
No auto-routing — users pick the variant that matches their screen once
and the browser remembers. Naming and icon conventions:

| | Mobile | Wide (desktop/tablet) |
|---|---|---|
| URL | `heating-zones` | `heating-zones-wide` |
| Title | `Heating` | `Heating (wide)` |
| Icon | thematic (`mdi:radiator`, `mdi:ev-station`, etc.) | `mdi:view-*` family |
| View type | `sections` (`max_columns: 4`) | `panel: true` |

**Bubble Card pop-up architecture:** v1 placed pop-ups in individual sections,
which caused them to render inline (defect). In v2 every pop-up for a
dashboard is grouped into a single top-level `type: vertical-stack` card, with
the pop-up definition (`card_type: pop-up`, `hash: "#..."`) as the first child
and its content following. This is the only reliable way to get modal overlay
rendering on mobile and desktop.

Dashboards (storage-mode):

- `home-overview.dashboard.yaml` — landing "Home" dashboard (2026-04 refresh:
  now mirrors the wide variant's content, mobile-optimised via a `sections`
  view with `max_columns: 2`). Full-width chips header (home count,
  lights-on, heating, doors open, grid-power, EV, low batteries, updates,
  away / eco, scenes, automations) identical to the wide dashboard; Weather
  and Presence & devices as paired sections (1 col each on tablets, stacked
  on phones); full-width Media-playing auto-entities row that hides when
  nothing is active; full-width Room temperatures 2-column grid of twelve
  stack-in-cards (mini-graph-card 6h sparkline + per-tile chips showing
  lights on/total and heating on/off), each tile tapping through to
  `/rooms-overview/default_view#<area>`; full-width Calendar card using
  `listWeek` initial view (`dayGridMonth` is unreadable on a phone). Power
  Flow, apexcharts room chart, quick-action chips, and the 6h logbook from
  v2 have been removed — power flow lives on `energy-ev`, scenes and quick
  actions live in the `#scenes` pop-up, and the logbook was retired.
  `#scenes` / `#automations` / `#people` Bubble Card pop-ups unchanged.
- `rooms-overview.dashboard.yaml` — replaces `ground-floor`, `first-floor`,
  `attic-floor`, and `media-rooms`. **Streamline-Card templated room tiles**
  grouped by floor (Ground / First / Attic) — Mushroom template-cards with
  vertical layout so labels survive on mobile. Each tile taps through to a
  **Bubble Card pop-up** (`#kitchen`, `#bedroom`, …) grouped into the first
  top-level vertical-stack. Pop-up contents per room are a
  `mushroom-climate-card` (where the room has a Wiser zone) plus per-area
  `entities` tables for lights / switches / environment / doors / scenes,
  and an optional `mushroom-media-player-card`. AMS attic sensors live only
  in the attic pop-up (deduped). Note: pop-up content uses stock
  `mushroom-climate-card` + `entities` (not `mini-climate-card` +
  `auto-entities` as earlier iterations intended).
- `heating-zones.dashboard.yaml` — Chips (operation mode, HW mode,
  active-heating count, Away / Eco / Comfort / DST toggles), **Heating
  actions** grid of mushroom-template buttons (Boost all 30m / Cancel
  overrides / Heat off / Boost HW), **Hot water actions** grid (Boost HW
  / Toggle HW / Cancel) + Hot-water-state entities table, **Zones**
  grid of eight stock `thermostat` cards with climate-hvac-modes
  features, **Trends & schedule** `tabbed-card` (Temperatures / Demand /
  Schedule apexcharts + Wiser schedule editor), Away-settings entities.
  iTRV/RoomStat telemetry no longer duplicated here — moved to
  `entity-health`.
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

Wide variants (v5, 2026-04 — panel-view rewrite):

**All seven wide dashboards now use `panel: true`.** The original v3/v4
sections-view layout was retired because its ~320px column min-width
clamped `max_columns: 4` to one effective column on typical desktop
viewports, leaving ~60% of the screen blank. Panel view uses a single
top-level `vertical-stack` at the root, with `horizontal-stack` children
for multi-column rows (halves, thirds, quarters) and `grid` only where
a true fixed-column tile grid is wanted. Section titles are rendered as
inline `type: markdown` cards because panel view has no section-title
concept. This pattern was validated on `home-overview-wide` first; the other six
were then rewritten to match.

**Wireframes:** a table-style wireframe of the seven `-wide` dashboards
lives as a Cursor Canvas at
`~/.cursor/projects/Users-hlardner-projects-personal-homelab/canvases/wide-dashboard-wireframes.canvas.tsx`
(open it via Cursor's canvas pane — the file lives in the per-workspace
Cursor config dir, not in this repo, because canvases are an IDE
artefact rather than version-controlled source). The canvas shows each
wide dashboard as a sequence of labelled boxes (chips rows, chart
panels, table halves, hero tiles) with approximate heights and tone
markers (chart / table / media / accent) so the high-level layout is
visible at a glance. It was the initial concept and drifts slightly
from the built-out dashboards — the per-dashboard layout paragraphs
below are authoritative for the current state; the canvas is kept as
the shared mental model for the row-spanning scheme.

Design principles (shared by all wide dashboards):

1. **`panel: true`** to escape the sections-view column clamp.
2. **Single top-level `vertical-stack`** with `horizontal-stack`/`grid`
   children. No nested sections.
3. **Width-native cards** — `apexcharts-card`, `statistics-graph`,
   `logbook-card`, dense `entities` tables — instead of mobile tile
   grids stretched to desktop widths.
4. **Side-by-side pairings** — state + history, control + chart, live +
   historical — so the extra horizontal space actually buys comparison.
5. **Density over scrolling.** Information that paginates on the mobile
   dashboards is surfaced inline on the wide ones.
6. **Hash navigation preserved.** Bubble Card pop-ups are grouped into a
   single vertical-stack exactly as on mobile.

Per-dashboard layout:

- `home-overview-wide.dashboard.yaml` — Canonical design. Extended chips
  row, Weather (simple-weather + 5-day forecast), Lights-on | Heating-on
  auto-entities pair, Room temperature 6×2 mini-graph grid, dynamic Media
  playing row, Calendar | Presence & devices, full-width 6h activity
  logbook.
- `rooms-overview-wide.dashboard.yaml` — Summary chips, **Room state
  tri-column table** (ground / first / attic) with `last-changed`
  secondary info and per-row tap→pop-up navigation, per-floor 24h
  apexcharts (ground vs first + attic) in a 50/50 row. Pop-ups per room
  retained.
- `heating-zones-wide.dashboard.yaml` — Combined chips + action row
  (mode, HW mode, active-heating count, Boost 30m / Cancel / Heat off /
  Boost HW / Toggle HW actions, Away / Eco / Comfort toggles), **4+4
  bare-thermostat grid** (no per-tile sparkline — controls only),
  full-width **`history-explorer-card`** with a single graph containing
  both zone temperatures (°C, smooth lines) and heating demand (0–100 %,
  stepped fill) — legend entries share names across the two series sets
  (e.g. both "Kitchen" temperature and "Kitchen" demand) so toggling a
  zone hides both its lines at once, full-width Wiser schedule editor,
  Hot water | Away settings halves. The v5 design paired each
  thermostat with a 24h apexcharts dual-axis sparkline inside
  `stack-in-card`; that was dropped in v5.1 (see Recent iterations).
- `energy-ev-wide.dashboard.yaml` — Power-flow + 7-day energy-flow
  apexchart 50/50 hero, full-width 7d hourly bar `statistics-graph`,
  Charger (Zappi) | Grid & meter (Harvi) detail tables 50/50, Charge
  mode chips row.
- `security-network-wide.dashboard.yaml` — Chips, **3 cameras + 1
  automations** quarters row, full-width 24h motion/contact timeline
  apexchart, **Security logbook | Presence & devices** halves, Contacts
  | Motion halves for per-sensor state.
- `system-maintenance-wide.dashboard.yaml` — Chips, **Pending updates |
  Unavailable entities** merged auto-entities halves (the v3 HACS/
  integration split was dropped; a single sorted list is more useful),
  **Backups & HA host | Printer** halves with the printer status table
  inlined (pop-up kept as a shortcut).
- `entity-health-wide.dashboard.yaml` — Chips, full-width mega battery
  `auto-entities` + `bar-card` table sorted worst-first, **7d battery
  levels | 7d HeatHub signal + SLZB core/zigbee temps** apexcharts 50/50,
  **Needs attention | Bridges & hubs** halves, **Wiser iTRV signal |
  Wiser iTRV battery** halves, **myenergi hardware | Harvi CTs** halves,
  full-width device last-seen list.

Automations:

- `review-managed-automations.yaml` — shared automations (critical
  connectivity, UniFi telemetry, presence lighting)

## Recent iterations

Chronological log of notable dashboard changes since the v5 panel-view
rewrite. Newer entries on top. Each entry notes what changed, why, and
which YAML/live config was touched so the previous state can be
reconstructed from Git history if needed.

### 2026-04 — `heating-zones-wide` v5.2: strip per-zone sparklines

- **Change:** removed the 24h `apexcharts-card` mini-graph from every
  zone; each of the eight `stack-in-card` wrappers collapsed to a bare
  `thermostat` card. The 4+4 grid is now pure control surface.
- **Why:** the dual-axis apexcharts per zone competed with the
  full-width history-explorer graph below and added visual noise
  without a clear use (the history-explorer already plots all zones on
  one comparable axis). Removing the sparklines reclaims vertical space
  for the thermostat rings.
- **Touched:** `heating-zones-wide.dashboard.yaml` (8× stack-in-card
  unwrap), pushed live via `ha_config_set_dashboard`.

### 2026-04 — `heating-zones-wide` v5.1: plotly → history-explorer combined graph

- **Change:** replaced the original per-room history chart (and the
  7-day stacked-demand apexchart that preceded it) with a single
  `custom:history-explorer-card` containing **two line graphs** —
  eight temperatures and eight heating-demand series — that share
  **legend-entry names per zone** so clicking "Kitchen" in either
  graph's legend hides both the Kitchen temperature line and its
  demand fill. Iteration path:
  1. Added both `custom:plotly-graph` and `custom:history-explorer-card`
     side-by-side for comparison.
  2. Both initially errored (Plotly wanted nested `yaxis.title.text`
     rather than a bare string; history-explorer rejected unsupported
     top-level keys like `title:` and `options.height:`).
  3. Iterated Plotly through dual subplots → single graph with demand
     as a stepped fill on a secondary axis → single graph with demand
     collapsed to heating-on/off markers via `map_y_numbers`.
  4. Dropped Plotly entirely. Its output was functional but rougher
     than history-explorer's (pan/zoom snappier, tooltips cleaner,
     decimation built-in).
  5. With two history-explorer graphs stacked, the two legends didn't
     link. Evaluated combining into **one** graph (single shared
     legend, mixed units) versus **two** graphs with matching
     per-entity display names across both. Chose the latter:
     temperatures on an auto-scaled axis (≈18–25 °C) stay readable
     while demand has its own fixed 0–100 range, and shared names are
     enough to make legend toggling feel unified.
- **Why client-side, not automation:** Home Assistant automations
  cannot read or mutate Lovelace client-side state (including
  card-level legend toggles). Linking the two legends had to be a
  card-level capability; history-explorer doesn't expose it directly,
  so the shared-name convention is the practical workaround.
- **Touched:** `heating-zones-wide.dashboard.yaml` (plotly-graph-card
  removed, history-explorer-card added, entity display names aligned
  between temperature and demand series).

### 2026-04 — wide-variant panel rewrite (v5)

- **Change:** all seven `-wide` dashboards converted from `sections`
  view (`max_columns: 4`) to `panel: true` with a single top-level
  `vertical-stack` + `horizontal-stack`/`grid` children.
- **Why:** the sections view's ~320 px column min-width clamped a
  `max_columns: 4` layout to a single effective column on typical
  desktop viewports, leaving ~60 % of the screen blank. Panel view
  bypasses the column clamp and lets width-native cards (apexcharts,
  statistics-graph, logbook-card, wide entities tables) fill the
  screen. Section titles were re-implemented as inline `type: markdown`
  cards because panel view has no section-title concept.
- **Touched:** all `*-wide.dashboard.yaml` files; wireframe canvas
  updated first to validate the pattern on `home-overview-wide`.

### 2026-04 — v2 dashboard split (mobile + wide)

- **Change:** every mobile `<name>` dashboard got a `<name>-wide`
  sibling, raising the sidebar count from seven to fourteen. Users pick
  the variant that suits their screen once.
- **Why:** one layout cannot be dense on a phone *and* fill a 27"
  monitor without wasting either horizontal space or readability. No
  user-agent auto-routing — the browser just remembers the last chosen
  sidebar link.
- **Touched:** seven new `*-wide.dashboard.yaml` files; README naming /
  icon conventions table.

### 2026-04 — `entity-health` extracted

- **Change:** introduced `entity-health.dashboard.yaml` +
  `entity-health-wide.dashboard.yaml` as a dedicated device/telemetry
  surface. Moved iTRV/RoomStat batteries & signal off `heating-zones`,
  Harvi CTs + myenergi hardware off `energy-ev`, sensor-battery
  summary + SLZB coordinator off `security-network`, and Zigbee /
  Wiser / HeatHub panels off `system-maintenance`.
- **Why:** the same battery and bridge tiles were duplicated across
  four dashboards. Consolidating makes the thematic dashboards leaner
  and gives device health a single authoritative view.
- **Touched:** new `entity-health*.dashboard.yaml`; equivalent
  sections stripped from the four source dashboards.

### 2026-04 — retirements

Removed from live HA and source YAML:

- `ground-floor`, `first-floor`, `attic-floor`, `media-rooms` →
  absorbed into `rooms-overview` via area-driven bubble-card pop-ups.
- `cameras-events`, `presence-network` → merged into
  `security-network`.
- `scenes-automations` → lifted into `home-overview` bubble-card
  pop-ups (`#scenes`, `#automations`).
- `office-dashboard`, `bedroom-dashboard`, `security-sensors` →
  retired earlier; see Git history.

## Plan (next)

Short list of dashboard work that is in scope but not yet delivered.
This is intentionally small — large re-designs go into Git history via
a new **Recent iterations** entry rather than living in a plan
section.

- **`rooms-overview` pop-up realignment.** Current mobile pop-ups use
  stock `mushroom-climate-card` + `entities` tables. The earlier
  concept called for `mini-climate-card` + `auto-entities` filtered by
  area, which would scale better as new entities appear in a room
  without hand-editing the dashboard. Open question: is the automation
  cost worth the loss of explicit control over what shows in each
  pop-up?
- **`heating-zones-wide` legend-link follow-up.** The shared-name
  convention works but a single combined graph (one legend, mixed
  °C + % units with a right-hand axis) is still on the table if
  `history-explorer-card` adds per-series y-axis assignment upstream.
  Revisit after the next card release.
- **Wireframe canvas refresh.** `wide-dashboard-wireframes.canvas.tsx`
  still reflects the v5 layout — notably it still shows per-zone
  sparklines on `heating-zones-wide` and the pre-history-explorer
  Plotly block. Update once the v5.2 layout has settled for a few
  weeks.
- **Mobile `home-overview` parity check.** The mobile variant was
  regenerated in 2026-04 to mirror the wide dashboard's chip row and
  weather/presence split; the Room-temperatures 6×2 grid is still
  stock stack-in-card + mini-graph. Keep as-is unless the wide grid
  layout changes materially.

## HACS / frontend card prerequisites

All custom cards are **HACS-managed** (installed via `ha_hacs_download` /
HACS UI, not hand-downloaded into `/config/www/`). HACS installs them into
`/config/www/community/<card>/` and registers the matching Lovelace resource
with a `?hacstag=<hash>` cache-buster. This means upgrades happen inside HACS
with no manual file shuffling. All seventeen cards across the three lists
below must be installed and enabled before the v5 dashboards will render.

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

**v5 additions (dashboard-rewrite era):**

- `history-explorer-card` — interactive multi-entity history with pan /
  zoom / decimation, used on `heating-zones-wide` for the combined
  temperature + heating-demand graphs. Replaced an earlier
  `custom:plotly-graph` experiment — see Recent iterations.
- `wiser-schedule-card` — full Wiser schedule editor (not the
  HACS-scheduler-card `scheduler-card` listed above; this one ships
  with the Drayton Wiser custom integration) used on
  `heating-zones-wide` for inline schedule editing.

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
