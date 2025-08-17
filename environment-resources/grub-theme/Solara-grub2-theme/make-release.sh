#! /bin/bash

OPEN_DIR=$(cd $(dirname $0) && pwd)

THEME_NAME=Solara

POSITION_VARIANTS=('left' 'right')
SCREEN_VARIANTS=('1080p' '2k' '4k')

positions=()
screens=()

if [[ "${#positions[@]}" -eq 0 ]] ; then
  positions=("${POSITION_VARIANTS[@]}")
fi

if [[ "${#screens[@]}" -eq 0 ]] ; then
  screens=("${SCREEN_VARIANTS[@]}")
fi

Tar_themes() {
  for position in "${positions[@]}"; do
      rm -rf ${THEME_NAME}-${position}-grub-themes.tar
      rm -rf ${THEME_NAME}-${position}-grub-themes.tar.xz
  done

  for position in "${positions[@]}"; do
      tar -Jcvf ${THEME_NAME}-${position}-grub-themes.tar.xz ${THEME_NAME}-${position}-grub-themes
  done
}

Clear_theme() {
  for position in "${positions[@]}"; do
    rm -rf ${THEME_NAME}-${position}-grub-themes
  done
}

for position in "${positions[@]}"; do
  for screen in "${screens[@]}"; do
    ./generate.sh -d "$OPEN_DIR/releases/${THEME_NAME}-${position}-grub-themes/${screen}" -p "${position}" -s "${screen}" -l default
    cp -rf "$OPEN_DIR/releases/"install "$OPEN_DIR/releases/${THEME_NAME}-${position}-grub-themes/${screen}"/install.sh
    cp -rf "$OPEN_DIR/backgrounds/preview-${position}.jpg" "$OPEN_DIR/releases/${THEME_NAME}-${position}-grub-themes/${screen}/preview.jpg"
    sed -i "s/grub_theme_name/${THEME_NAME}-${position}/g" "$OPEN_DIR/releases/${THEME_NAME}-${position}-grub-themes/${screen}"/install.sh
  done
done

cd "$OPEN_DIR/releases"

Tar_themes && Clear_theme

