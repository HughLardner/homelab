# Home Assistant Review

Date: 2026-03-22

## Executive Summary

Home Assistant is healthy, valid, and already useful for lighting, heating, Zigbee, and operational notifications. The biggest issue is not platform stability, but configuration drift: the live `/config` volume now contains the real source of truth for dashboards, automations, OIDC auth, persons, and storage-managed state, while the Git repo mostly describes deployment.

The highest-value improvements are:

1. Bring the live Home Assistant config under review and partial version control.
2. Add real presence and network context using UniFi clients and mobile app trackers.
3. Replace the low-value `map` dashboard with a `Presence / Network` dashboard.
4. Add a small set of high-signal automations around device health, presence, and energy.

## Status Update

Completed after this review:

- Repo baseline updated: `kubernetes/applications/home-assistant/values.yaml` now includes the live `auth_oidc` block.
- New live dashboard created: `presence-network`.
- New live automations created:
  - `automation.health_low_battery_alert`
  - `automation.health_critical_connectivity_alert`
  - `automation.health_backup_stale_alert`
- UniFi client trackers enabled and mapped:
  - `person.hugh` -> `device_tracker.hugh_mobile` + `device_tracker.pixel_9_pro`
  - `person.marie` -> `device_tracker.marie_s_a56`
- Home zone location repaired from `0,0` to the real house coordinates so companion-app GPS presence works again.
- `presence-network` expanded with UniFi infrastructure, critical clients, and phone trackers.
- New UniFi-aware automations created:
  - `automation.health_unifi_telemetry_alert`
  - `automation.presence_arrival_after_dark`
- Stable shared dashboard and automation definitions exported into `kubernetes/applications/home-assistant/managed-state/`.
- Home Assistant configuration re-validated successfully after the changes.

Still outstanding:

- The legacy `map` dashboard still exists and has not yet been retired or replaced in-place.
- Marie does not yet have a companion-app tracker, so her current presence model is UniFi-backed only.
- Hugh's chosen UniFi client `device_tracker.pixel_9_pro` (`d8:89`) is still reporting `not_home` even though the phone is expected on the home UniFi estate, so his reliable state currently comes from the repaired companion-app GPS tracker.
- The repo now has a documented managed-state pattern, but the shared HA UI state is not yet applied automatically from Git.

## Live State Snapshot

- Home Assistant version: `2026.3.3`
- Install type: `Home Assistant Container`
- Entities: `380`
- Areas: `16`
- Dashboards: `6` storage dashboards visible in the sidebar, including the new `presence-network` dashboard
- Automations: `31`
- Integrations loaded: `13`
- Dashboard resources: `2`
- Configuration check: `valid`

### Loaded integrations

- Core/default: `sun`, `shopping_list`, `google_translate`, `radio_browser`, `backup`, `go2rtc`
- Custom/user: `mqtt`, `shelly`, `wiser`, `myenergi`, `s3_compatible`, `hacs`, `unifi`
- Auth: `auth_oidc`

### HACS state

- Installed HACS integrations: `6`
- Installed HACS Lovelace cards: `0`
- Registered Lovelace resources: two Wiser resources
  - `/wiser/wiser-schedule-card.js?v=1.5.0`
  - `/wiser/wiser-zigbee-card.js?v=2.1.2`

## Live Config Review

### What is actually in `/config`

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml` (empty)
- `scenes.yaml` (empty)
- `.storage/*` with dashboard, registry, auth, person, and Lovelace data
- `custom_components/`
  - `auth_oidc`
  - `hacs`
  - `myenergi`
  - `nodered`
  - `s3_compatible`
  - `wiser`
- `packages/plex.yaml`
- default blueprints only

### Important drift from Git

#### 1. OIDC drift has been fixed in the repo baseline

The live `configuration.yaml` contains:

```yaml
auth_oidc:
  client_id: home-assistant
  client_secret: !env_var OIDC_CLIENT_SECRET
  discovery_url: https://auth.silverseekers.org/.well-known/openid-configuration
  display_name: "Authelia"
  features:
    force_https: true
    automatic_user_linking: true
```

Status: done.

That block has now been added to `kubernetes/applications/home-assistant/values.yaml`, so the repo baseline matches the live authentication setup.

#### 2. Dashboards are still live-only, but a new review-driven dashboard has been added

The visible dashboards are storage-managed and live in `.storage`, not the repo:

- `home-overview`
- `office-dashboard`
- `bedroom-dashboard`
- `security-sensors`
- `map`
- `presence-network`

Status: partially addressed.

The new `presence-network` dashboard now provides a useful presence/platform-health view using currently available entities, but the dashboards are still storage-managed and not yet recoverable from Git.

#### 3. Automations are still mostly live-only except Plex, plus the new health automations

The repo only manages `packages/plex.yaml`. The real automation set is in live `automations.yaml`.

Automation themes currently present:

- Motion lighting: office, hall, landing
- Door alerting: front door night notification
- Time-of-day lighting: morning kitchen, sunset dimming, bedtime
- MQTT button workflows: bedroom, kitchen, office
- Device timer: clothes rail
- Ops: Kubernetes Alertmanager webhook notification
- Platform package: Plex scale up/down toggle
- Health monitoring: battery alerts, critical connectivity alerts, stale backup alerts

Status: partially addressed.

Useful new automations have been added live, but they still need to be normalized into a Git-managed pattern if you want the repo to become the durable source of truth.

#### 4. Repo docs no longer match runtime reality

The repo README still implies automatic owner creation and automatic HACS install, but the chart values currently have both disabled. The runtime config also depends on manual live changes that are not reflected in Git.

#### 5. Presence is now meaningfully configured, with one remaining gap

- `person.admin` remains linked to `device_tracker.hugh_mobile`
- `person.hugh` is now linked to `device_tracker.hugh_mobile` and the UniFi client `device_tracker.pixel_9_pro`
- `person.marie` is now linked to the UniFi client `device_tracker.marie_s_a56`
- The broken `zone.home` definition was corrected after it was found to be at `0,0`; Hugh now resolves to `home` again via the companion app.
- Hugh's UniFi client is the `Pixel-9-Pro` device with MAC suffix `d8:89`
- Marie does not yet have a companion-app tracker in HA, so her model is not fully blended yet
- `map` still exists, but `presence-network` is now the useful presence dashboard

## UniFi To Home Assistant Mapping

Status: updated after the UniFi integration was added to Home Assistant.

### UniFi network summary

Visible UniFi networks relevant to Home Assistant:

- `Default` - `192.168.86.0/24`
- `Homelab` - `192.168.10.0/24`
- `IoT` - `192.168.40.0/24`
- `pi-hole DNS` - `192.168.100.0/24`
- `Guest` - `192.168.99.0/24`

Visible UniFi infrastructure:

- `Cloud Gateway Ultra`
- `Marie's Office Access Point`
- `USW-Lite-8-PoE`
- `U6-Mesh`

### Devices already represented in Home Assistant

- `WiserHeat03BE6F` -> strongly represented through the `wiser` integration
- `Zappi` -> strongly represented through the `myenergi` integration
- `shellydimmer2-8CAAB55580B6` -> represented through the `shelly` integration
- `SLZB-MR3U` -> indirectly represented through Zigbee2MQTT bridge entities and Zigbee devices
- `Hugh Mobile` -> represented through the mobile app `device_tracker.hugh_mobile`
- `Cloud Gateway Ultra` -> represented through the `unifi` integration
- `Marie's Office Access Point` -> represented through the `unifi` integration
- `USW-Lite-8-PoE` -> represented through the `unifi` integration
- `U6-Mesh` -> represented through the `unifi` integration
- `proxmox server`, `homeassistant`, `Sky Box`, `SLZB-MR3U`, and other network devices now appear as UniFi-backed `device_tracker` entities

### Newly exposed UniFi entity types

The UniFi integration is now exposing useful infrastructure entities, including:

- `device_tracker.*` entities for gateway, APs, switch, and selected clients
- CPU and memory utilization sensors for UniFi devices
- restart buttons for some managed UniFi devices
- switch entities for UniFi-managed network features and routes
- client SSID/context can still be incomplete in the current tooling, so live UniFi client presence should be judged primarily by the HA entities rather than the MCP list output alone

Examples observed during this review:

- `device_tracker.cloud_gateway_ultra`
- `device_tracker.marie_s_office_access_point`
- `device_tracker.u6_mesh`
- `sensor.cloud_gateway_ultra_cpu_utilization`
- `sensor.cloud_gateway_ultra_memory_utilization`
- `sensor.u6_mesh_cpu_utilization`
- `sensor.usw_lite_8_poe_cpu_utilization`
- `button.marie_s_office_access_point_restart`

### Devices visible on UniFi but not meaningfully represented in Home Assistant

- Additional household device presence from UniFi or companion apps beyond Hugh and Marie
- `SonosZP` speakers
- `Nest-Hello-f00b`, `Nest-9960`, `Nest-797E`

Refined conclusion:

- infrastructure visibility is now in good shape
- household-presence visibility is still weak
- media and Nest-class devices are still the clearest integration opportunities

### Recommendation

Use the new UniFi integration for:

- client presence
- gateway and AP health
- network device availability
- richer presence logic for the `person` entities

That integration step is now done. The next step is to connect the exposed UniFi entities to dashboards, person mappings, and alerting.

## Dashboard Review

### `home-overview` - Keep and expand

Current strengths:

- good top-level summary of lights, security, climate, and automations
- simple tile layout
- already useful as the main landing page

Gaps:

- no people or presence
- no network health
- no energy view
- no heating summary despite strong Wiser coverage

### `office-dashboard` - Keep

Current strengths:

- focused room dashboard
- brightness controls on key lights
- motion sensor visibility
- automation toggles
- Plex control surfaced in the right place

Gaps:

- no temperature or heating control beyond passive sensors
- no occupancy history or connectivity health for office devices

### `bedroom-dashboard` - Keep but merge into a room pattern

Current strengths:

- clear lamp controls
- bedtime scene and bedtime automation are easy to reach

Gaps:

- very narrow scope
- no battery, button, or heating context

### `security-sensors` - Keep, but broaden into health + security

Current strengths:

- contact/motion visibility
- 24-hour history graph
- battery panel is practical

Gaps:

- focused only on a subset of sensors
- no offline/unavailable status
- no UniFi camera, AP, or device health correlation yet, even though UniFi telemetry is now available

### `map` - Retire once you are comfortable with the replacement

Current strengths:

- none at the moment beyond future potential

Problems:

- it is no longer the dashboard with the best presence information
- it duplicates the role now covered better by `presence-network`
- it is still a legacy storage dashboard

Status: replacement ready.

Instead of forcing a risky in-place edit to the legacy `map` dashboard, a new `presence-network` dashboard was created safely and is now the better view. The next cleanup step is to retire `map` in the UI when you are happy with the new dashboard.

### `presence-network` - New dashboard created from this review

Current strengths:

- surfaces `person` entities plus Hugh's mobile tracker and the UniFi-backed phone clients
- separates household presence, critical clients, UniFi infrastructure, UniFi telemetry, and platform health
- gives a practical platform-health view for Zigbee2MQTT, Wiser, backup status, and Plex
- is now the right shared dashboard to keep normalizing into Git

Current gaps:

- Marie still lacks a companion-app tracker
- `map` has not yet been removed from the sidebar
- the dashboard is still storage-managed at runtime even though its source is now exported into Git

### Target dashboard structure

Recommended end state:

1. `Home`
   - lights
   - security
   - climate
   - quick actions
   - active alerts
2. `Presence / Network`
   - people
   - phones/tablets
   - UniFi gateway/AP status
   - critical client availability
3. `Energy / Heating`
   - Zappi/myenergi
   - Wiser temperatures and demands
   - power-heavy devices
4. `Office`
   - keep as a room-specific view
5. `Bedroom`
   - keep as a room-specific view

## Automation Review

### What is already working well

- motion lighting is well covered and thoughtfully handles day/night brightness
- the bedtime flow is small but effective
- physical MQTT button flows are set up for bedroom, kitchen, and office
- HA already receives Kubernetes alerts, which is a good homelab-specific use of the platform

### Gaps worth fixing first

- the new UniFi-aware automations should be observed for a few days and then tuned if thresholds are noisy
- Marie still lacks a companion-app tracker, so her presence is not yet fully blended
- no energy or EV-specific automations despite strong myenergi exposure
- Kubernetes alerts still need the same phone-delivery treatment now added to the health alerts

## Recommended Automations

These are the first 5 automations worth implementing.

### 1. Presence-driven arrival / departure

Trigger on:

- `device_tracker` or UniFi client presence for Hugh and Marie

Behavior:

- mark people home/not_home reliably
- optionally disable aggressive motion-off logic when someone is still home
- optionally turn on an arrival scene after sunset

Why first:

- it unlocks the `map` replacement
- it improves user-level usefulness more than any other missing feature

### 2. Critical device offline alert

Trigger on unavailable/offline state for:

- Wiser hub
- Zigbee2MQTT bridge
- Zappi/myenergi
- Shelly dimmer
- Cloud Gateway Ultra or primary AP once UniFi is integrated

Behavior:

- create persistent notification
- optionally send mobile notification

Why first:

- this gives HA real operational value for the house

Status: implemented and expanded.

Current coverage now includes:

- Zigbee2MQTT bridge
- Wiser cloud
- Cloud Gateway Ultra
- Marie's Office AP
- USW-Lite-8-PoE
- U6-Mesh

Delivery now includes both persistent notifications and `notify.mobile_app_hugh_mobile`.

### 3. Sensor battery and health digest

Trigger on:

- battery below threshold
- entities becoming `unavailable`

Behavior:

- daily digest or immediate alert for severe cases
- include room/device name and last seen status

Why first:

- the current dashboards already expose many battery entities, but no workflow acts on them

Status: partially implemented as `automation.health_low_battery_alert`.

Current limitation:

- this is event-driven persistent notification, not yet a consolidated daily digest

### 4. EV charging / energy awareness

Trigger on:

- Zappi state changes
- optional tariff window
- optional home occupancy or nighttime schedule

Behavior:

- notify when vehicle is plugged in but not charging
- notify when charge completes
- optionally set charge mode by schedule if that fits your actual use

Why first:

- the `myenergi` integration already exposes rich data, but the UI and automations are not using it yet

### 5. Replace persistent-only K8s alerts with phone delivery

Trigger on:

- existing `alertmanager-k8s` webhook

Behavior:

- keep persistent notification
- add `notify.mobile_app_*` services once the companion apps are in place

Why first:

- the logic already exists and only needs better delivery targets

Status: partially addressed.

Dependency status:

- `notify.mobile_app_hugh_mobile` is available and is now used by the health alerts
- the same pattern should be applied to the Kubernetes alert flow next

## Version Control Recommendations

### Move into Git

- `configuration.yaml` baseline, including the `auth_oidc` block
- stable automations from `automations.yaml`
- any reusable scenes or scripts once they become non-empty
- dashboard YAML for the main shared dashboards
- any non-secret package files
- a small documented mapping of people to trackers

Status update:

- the `auth_oidc` baseline item is done
- the shared `presence-network` dashboard and the current review-driven automations are now exported under `kubernetes/applications/home-assistant/managed-state/`
- the UniFi entity model is now reflected in the managed dashboard and automation source files

### Keep UI-managed or storage-managed unless they stabilize

- experimental dashboard layout tweaks
- per-user UI preferences
- auth/session metadata in `.storage`
- device/entity registries
- traces, recorder state, backup metadata

### Suggested split

- Git manages shared behavior
  - auth setup
  - automations
  - main dashboards
  - packages
  - scripts
- HA storage manages operational state
  - registries
  - traces
  - sessions
  - per-user UI metadata

## Concrete Next Steps

1. Retire the legacy `map` dashboard from the UI if `presence-network` feels good after a short trial period.
2. Add Marie's companion app if you want her presence model to become fully blended instead of UniFi-only.
3. Apply the new phone-delivery pattern to the Kubernetes Alertmanager automation.
4. Add the next high-value automation from this review:
   - EV charging / energy awareness
   - daily battery or health digest
5. Decide whether to build a real repo-to-HA sync path for `managed-state/` or keep using the documented manual export/apply workflow.
