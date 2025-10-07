#!/usr/bin/env bash
set -uo pipefail

LOGFILE="/tmp/lid-handler.log"
LOCK_CMD="swaylock -f -c 000000"

INTERNAL="eDP-1"

if [ -z "$INTERNAL" ]; then
  INTERNAL=$(hyprctl monitors 2>/dev/null | grep -Eo 'eDP(-[0-9]+)?|LVDS(-[0-9]+)?' | head -n1 || true)
fi

log() {
  echo "$(date '+%F %T') $1" >> "$LOGFILE"
}

EXTERNALS=$(hyprctl monitors 2>/dev/null | grep "Monitor" | grep -v "$INTERNAL" || true)

case "${1:-}" in
  close)
    log "Lid closed (internal='$INTERNAL')"
    if [ -n "$EXTERNALS" ]; then
      log "External monitor(s) detected -> disabling internal. Details: $(echo "$EXTERNALS" | tr '\n' ' | ')"
      hyprctl dispatch dpms off "$INTERNAL"
      hyprctl keyword monitor "$INTERNAL,disable"
      log "Skipped locking because external monitor present."
    else
      log "No external monitor -> disabling internal and locking"
      hyprctl dispatch dpms off "$INTERNAL"
      hyprctl keyword monitor "$INTERNAL,disable"
      [ -n "$LOCK_CMD" ] && eval "$LOCK_CMD" &
    fi
    ;;
  open)
    log "Lid opened"
    hyprctl keyword monitor "$INTERNAL,preferred,auto,1"
    hyprctl dispatch dpms on "$INTERNAL"
    log "Internal re-enabled"
    ;;
  *)
    log "Bad/empty argument: '$1'"
    ;;
esac
