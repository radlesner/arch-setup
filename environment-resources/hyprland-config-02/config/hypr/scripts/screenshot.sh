#!/bin/bash

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"

file="$dir/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

case "$1" in
  area)
    geometry=$(slurp)

    [ -z "$geometry" ] && exit 0

    grim -g "$geometry" - \
    | tee "$file" \
    | wl-copy
    ;;
  full)
    grim - | tee "$file" | wl-copy
    ;;
esac

notify-send "Screenshot saved" "$file"