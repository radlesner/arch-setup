#!/usr/bin/env bash
set -euo pipefail

log_file="/tmp/hyprland-lid-handler.log"
lockscreen="swaylock -f -i ~/.config/wallpapers/firewatch-01-blur-0x25.jpeg"

internal_monitor="eDP-1"

if [ -z "$internal_monitor" ]; then
  internal_monitor=$(hyprctl monitors 2>/dev/null | grep -Eo 'eDP(-[0-9]+)?|LVDS(-[0-9]+)?' | head -n1 || true)
fi

log() {
  echo "$(date '+%F %T') $1" >> "$log_file"
}

external_monitors=$(hyprctl monitors 2>/dev/null | grep "Monitor" | grep -v "$internal_monitor" || true)

case "${1:-}" in
  close)
    log "Lid closed (internal='$internal_monitor')"
    if [ -n "$external_monitors" ]; then
      log "External monitor(s) detected -> disabling internal. Details: $(echo "$external_monitors" | tr '\n' ' | ')"
      hyprctl keyword monitor "$internal_monitor,disable"
      log "Skipped locking because external monitor present."
    else
      log "No external monitor -> disabling internal and locking"
      hyprctl keyword monitor "$internal_monitor,disable"
      [ -n "$lockscreen" ] && eval "$lockscreen"
    fi
    ;;
  open)
    log "Lid opened"
    hyprctl keyword monitor "$internal_monitor,preferred,auto,1"
    log "Internal re-enabled"
    ;;
  lock-only)
    eval "$lockscreen"
    ;;
  *)
    log "Bad/empty argument: '$1'"
    ;;
esac
