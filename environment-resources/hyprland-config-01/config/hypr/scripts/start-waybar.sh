#!/bin/bash

LOG_FILE="/tmp/waybar.log"

killall waybar 2>/dev/null

export GSK_RENDERER=cairo
export LIBGL_ALWAYS_SOFTWARE=1

echo "==============================" >> "$LOG_FILE"
echo "Waybar start: $(date)" >> "$LOG_FILE"
echo "==============================" >> "$LOG_FILE"

waybar \
  --config ~/.config/waybar/hyprland/config.json \
  --style ~/.config/waybar/hyprland/style.css \
  >> "$LOG_FILE" 2>&1