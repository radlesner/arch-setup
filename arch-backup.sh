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

do_backup_local() {
  echo "${BLUE}[i] Starting backup.${RESET}"
  mkdir -p "$BACKUP_DIR"

  if [ ! -f "$LIST" ]; then
    echo "${RED}[!] No list file: $LIST${RESET}"
    exit 1
  fi

  while read -r ITEM; do
    [[ -z "$ITEM" || "$ITEM" =~ ^# ]] && continue
      ITEM_EXPANDED=$(eval echo "$ITEM")
      ITEM_EXPANDED=$(realpath -m "$ITEM_EXPANDED")

      if [ -e "$ITEM_EXPANDED" ]; then
        echo ">>> Copying: $ITEM_EXPANDED"
        rsync -a --relative "$ITEM_EXPANDED" "$BACKUP_DIR"
      else
        echo "${YELLOW}>>> File or directory not found: $ITEM_EXPANDED${RESET}"
      fi
  done < "$LIST"

  echo "${GREEN}[✓] Backup completed: $BACKUP_DIR${RESET}"
}

do_restore_local() {
  if [ -z "$1" ]; then
    echo "${RED}[!] You must provide a backup directory (e.g. $BACKUP_BASE/$DATE)${RESET}"
    exit 1
  fi

  SRC="$1"

  if [ ! -d "$SRC" ]; then
    echo "${RED}[!] Backup directory not found: $SRC${RESET}"
    exit 1
  fi

  echo "${BLUE}[i] Restoring backup from $SRC${RESET}"

  cd "$SRC" || exit 1
  rsync -a --relative . /

  echo "${GREEN}[✓] Restore completed.${RESET}"
}

case "$1" in
  --backup-local)
    do_backup_local
    ;;
  --restore-local)
    do_restore_local "$2"
    ;;
  *)
    echo ">>> System installation options:"
    echo "    --backup-local                     - Creating a local disk backup"
    echo "    --restore-local <backup_directory> - Restoring a local backup"
    exit 1
    ;;
esac
