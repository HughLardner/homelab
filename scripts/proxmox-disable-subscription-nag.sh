#!/usr/bin/env bash
#
# proxmox-disable-subscription-nag.sh
#
# Disables the Proxmox VE web UI "No valid subscription" dialog by adjusting
# the subscription status check in proxmoxlib.js (proxmox-widget-toolkit).
#
# Run on the Proxmox node as root (SSH or Datacenter -> Shell).
# Package upgrades that replace proxmox-widget-toolkit may restore the nag;
# re-run this script after such updates.
#
# Usage:
#   sudo ./scripts/proxmox-disable-subscription-nag.sh
#   sudo ./scripts/proxmox-disable-subscription-nag.sh --dry-run
#   sudo ./scripts/proxmox-disable-subscription-nag.sh --no-restart
#

set -euo pipefail

readonly PROXMOXLIB="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
readonly PATCH_MARKER="NoMoreNagging"

dry_run=0
no_restart=0

usage() {
  cat <<'EOF'
Disable the Proxmox VE "No valid subscription" web UI dialog (proxmoxlib.js).

Usage: proxmox-disable-subscription-nag.sh [options]

Options:
  --dry-run     Show actions only; do not modify files or restart services
  --no-restart  Do not restart pveproxy after patching
  -h, --help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --no-restart) no_restart=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

if [[ "$(id -u)" -ne 0 ]]; then
  err "Run as root (e.g. sudo $0)."
  exit 1
fi

if [[ ! -f "$PROXMOXLIB" ]]; then
  err "File not found: $PROXMOXLIB (is this a Proxmox VE node?)"
  exit 1
fi

if grep -q "${PATCH_MARKER}" "$PROXMOXLIB" 2>/dev/null; then
  log "Already patched (found '${PATCH_MARKER}' in ${PROXMOXLIB}). Nothing to do."
  exit 0
fi

# Match only the subscription status check, not other uses of "!" on the same line (e.g. !res).
if ! perl -0777 -ne 'exit(/toLowerCase\s*\(\)\s*!==\s*\x27active\x27/ ? 0 : 1)' "$PROXMOXLIB"; then
  err "Expected pattern not found: toLowerCase() !== 'active' (possibly different quoting or minified)."
  err "Proxmox may have changed the UI; inspect ${PROXMOXLIB} manually."
  exit 1
fi

backup="${PROXMOXLIB}.bak.$(date +%Y%m%d%H%M%S)"
if [[ "$dry_run" -eq 1 ]]; then
  log "[dry-run] Would copy ${PROXMOXLIB} -> ${backup}"
  log "[dry-run] Would run perl in-place replace on toLowerCase() !== 'active'"
  [[ "$no_restart" -eq 1 ]] || log "[dry-run] Would: systemctl restart pveproxy"
  exit 0
fi

cp -a "$PROXMOXLIB" "$backup"
log "Backup: ${backup}"

# Turn toLowerCase() !== 'active' into toLowerCase() == '<marker>' so the clause is never true
# for real API values. Do not use sed "s/!//" on the whole line — that can break !res on the same if.
export PMX_NAG_MARKER="$PATCH_MARKER"
perl -i -pe 's/toLowerCase\s*\(\)\s*!==\s*\x27active\x27/toLowerCase() == \x27$ENV{PMX_NAG_MARKER}\x27/g' "$PROXMOXLIB"

# If the old check is still present, the patch did not apply (exit 0 from perl => still broken).
if perl -0777 -ne 'exit(/toLowerCase\s*\(\)\s*!==\s*\x27active\x27/ ? 0 : 1)' "$PROXMOXLIB"; then
  err "Patch may have failed: toLowerCase() !== 'active' still present."
  err "Restore with: cp -a ${backup} ${PROXMOXLIB}"
  exit 1
fi

log "Patched ${PROXMOXLIB}"

if [[ "$no_restart" -eq 0 ]]; then
  systemctl restart pveproxy.service
  log "Restarted pveproxy.service. Hard-refresh your browser (cache) when testing."
else
  log "Skipped pveproxy restart; run: systemctl restart pveproxy.service"
fi
