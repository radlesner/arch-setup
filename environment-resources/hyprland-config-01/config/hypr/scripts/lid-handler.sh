#!/usr/bin/env bash
set -euo pipefail

log_file="/tmp/hypr-lid-handler.log"
scripts_dir="$HOME/.config/hypr/scripts"
disable_script="$scripts_dir/disable-monitor.sh"
lockscreen='swaylock -f -i ~/.config/wallpapers/firewatch-01-blur-0x25.jpeg'

log() {
  echo "$(date '+%F %T') $1" >> "$log_file"
}

# Detect internal monitor
internal_monitor=$(
  hyprctl monitors all 2>/dev/null \
  | grep "Monitor" \
  | grep -Eo 'eDP-[0-9]+|eDP|LVDS-[0-9]+|LVDS' \
  | head -n1
)

case "${1:-}" in

close)
    log "Lid closed"

    external_monitors=$(
      hyprctl monitors 2>/dev/null \
      | grep "Monitor" \
      | grep -v "$internal_monitor" || true
    )

    # External monitor connected
    if [ -n "$external_monitors" ]; then
      log "External monitor detected"

      if [ -x "$disable_script" ]; then
        "$disable_script"
        log "Executed disable-monitor.sh"
      else
        log "disable-monitor.sh missing or not executable"
      fi
    else
      log "No external monitor detected -> locking"

      if ! pgrep -x swaylock >/dev/null; then
        eval "$lockscreen" &
      fi
    fi
    ;;
  open)
    log "Lid opened"
      if [ -x "$disable_script" ]; then
        "$disable_script"
        log "Executed disable-monitor.sh for enable"
    else
      log "disable-monitor.sh missing or not executable"
    fi
    ;;
  lock-only)
    eval "$lockscreen" &
    ;;
  *)
    log "Invalid argument: ${1:-}"
    exit 1
    ;;
esac