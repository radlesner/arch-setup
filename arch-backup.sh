#!/bin/bash
#
# Auto Arch Setup Script
# Author: Radoslaw Lesner (https://github.com/radlesner)
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script. If not, see <https://www.gnu.org/licenses/>.

set -e

GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RED=$'\e[31m'
BLUE=$'\e[94m'
RESET=$'\e[0m'

LIST="backup_list"
BACKUP_BASE="./backup"
DATE=$(date +%Y%m%d-%H%M)
BACKUP_DIR="$BACKUP_BASE/$DATE"

do_backup() {
  mkdir -p "$BACKUP_DIR"

  if [ ! -f "$LIST" ]; then
    echo "❌ No list file: $LIST"
    exit 1
  fi

  while read -r ITEM; do
    [[ -z "$ITEM" || "$ITEM" =~ ^# ]] && continue
      ITEM_EXPANDED=$(eval echo "$ITEM")
      ITEM_EXPANDED=$(realpath -m "$ITEM_EXPANDED")

      if [ -e "$ITEM_EXPANDED" ]; then
        echo "➡️  Copying: $ITEM_EXPANDED"
        rsync -a --relative "$ITEM_EXPANDED" "$BACKUP_DIR"
      else
        echo "⚠️  File not found: $ITEM_EXPANDED"
      fi
  done < "$LIST"

  echo "✅ Backup completed: $BACKUP_DIR"
}

do_restore() {
  if [ -z "$1" ]; then
    echo "❌ You must provide a backup directory (np. $BACKUP_BASE/$DATE)"
    exit 1
  fi

  SRC="$1"

  if [ ! -d "$SRC" ]; then
    echo "❌ Backup directory not found: $SRC"
    exit 1
  fi

  echo "➡️  Restoring backup from $SRC"

  # Przechodzimy do katalogu backupu i kopiujemy wszystko z zachowaniem ścieżek
  cd "$SRC" || exit 1
  rsync -a --relative . /

  echo "✅ Restore completed."
}

case "$1" in
  --backup)
    do_backup
    ;;
  --restore)
    do_restore "$2"
    ;;
  *)
    echo "Usage: $0 {--backup|--restore <backup_directory>}"
    exit 1
    ;;
esac
