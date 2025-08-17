#!/bin/bash

INKSCAPE="/usr/bin/inkscape"
OPTIPNG="/usr/bin/optipng"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

THEME_VARIANTS=('background' 'preview')
SIDE_VARIANTS=('-left' '-right')

render_background() {
  local theme="${1}"
  local side="${2}"

  local FILEID="${theme}${side}"

  if [[ -f "$FILEID.jpg" ]]; then
    echo "$FILEID exists"
  else
    echo -e "\nRendering $FILEID.png"
    $INKSCAPE "--export-id=$FILEID" \
              "--export-dpi=96" \
              "--export-id-only" \
              "--export-filename=$FILEID.png" background.svg >/dev/null
    convert "$FILEID.png" "$FILEID.jpg"
  fi

  rm -rf "$FILEID.png"
}

for theme in "${THEME_VARIANTS[@]}"; do
  for side in "${SIDE_VARIANTS[@]}"; do
    render_background "${theme}" "${side}"
  done
done

exit 0
