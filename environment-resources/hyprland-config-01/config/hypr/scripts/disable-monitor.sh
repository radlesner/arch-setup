#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Hyprland internal monitor toggle
# Hyprland 0.55+ / Lua config
# ============================================

log_file="/tmp/toggle-internal-monitor.log"

log() {
  echo "$(date '+%F %T') $1" >> "$log_file"
}

notify() {
  notify-send "Monitor Toggle" "$1"
}

# Detect internal monitor
internal_monitor=$(
  hyprctl monitors all 2>/dev/null |
    grep "Monitor" |
    grep -Eo 'eDP-[0-9]+|eDP|LVDS-[0-9]+|LVDS' |
    head -n1
)

if [ -z "${internal_monitor:-}" ]; then
  log "Could not detect internal monitor"
  notify "Could not detect internal monitor"
  exit 1
fi

# Detect external monitors
external_monitors=$(
  hyprctl monitors 2>/dev/null |
    grep "Monitor" |
    grep -v "$internal_monitor" || true
)

# Refuse to disable internal monitor without external display
if [ -z "$external_monitors" ]; then
  log "No external monitor detected, refusing to toggle $internal_monitor"
  notify "No external monitor connected"
  exit 0
fi

# Check current state using Hyprland's disabled field
monitor_info=$(
  hyprctl monitors all 2>/dev/null |
    grep -A30 "^Monitor $internal_monitor "
)

if echo "$monitor_info" | grep -q "disabled: false"; then
  # Internal monitor enabled -> disable it
  log "Disabling internal monitor: $internal_monitor"

  hyprctl eval \
    "hl.monitor({output = '$internal_monitor', disabled = true})"

  notify "Disabled $internal_monitor"
  log "Disabled $internal_monitor"

else
  # Internal monitor disabled -> enable it
  log "Enabling internal monitor: $internal_monitor"

  hyprctl eval \
    "hl.monitor({output = '$internal_monitor', disabled = false})"

  notify "Enabled $internal_monitor"
  log "Enabled $internal_monitor"
fi
