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

color_green=$'\e[32m'
color_yellow=$'\e[33m'
color_red=$'\e[31m'
color_blue=$'\e[94m'
color_reset=$'\e[0m'

char_success="+"
char_warn="!"
char_error="x"
char_info="i"
char_qa="?"

log_info() { echo -e "${color_blue}[${char_info}] $1${color_reset} "; }
log_error() { echo -e "${color_red}[${char_error}] $1${color_reset} "; }
log_qa() { printf "${color_yellow}[${char_qa}] %s${color_reset} " "$1"; }
log_succes() { echo -e "${color_green}[${char_success}] $1${color_reset}"; }

LIST="backup_list"
BACKUP_BASE="./backup"
date=$(date +%Y%m%d-%H%M)
BACKUP_DIR="$BACKUP_BASE/$(whoami)-on-$(hostname)-backup-$date"

do_backup_local() {
  log_info "Starting backup to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  if [ ! -f "$LIST" ]; then
    log_error "No list file: $LIST"
    exit 1
  fi

  while read -r ITEM; do
    [[ -z "$ITEM" || "$ITEM" =~ ^# ]] && continue
      ITEM_EXPANDED=$(eval echo "$ITEM")
      ITEM_EXPANDED=$(realpath -m "$ITEM_EXPANDED")

      if [ -e "$ITEM_EXPANDED" ]; then
        echo "--> Copying: $ITEM_EXPANDED"
        rsync -a --relative "$ITEM_EXPANDED" "$BACKUP_DIR"
      else
        echo "${color_yellow}--> File or directory not found: $ITEM_EXPANDED${color_reset}"
      fi
  done < "$LIST"

  log_succes "Backup completed: $BACKUP_DIR"
}

do_restore_local() {
  if [ -z "$1" ]; then
    log_error "You must provide a backup directory (e.g. $BACKUP_BASE/$date)"
    exit 1
  fi

  src="$1"

  if [ ! -d "$src" ]; then
    log_error "Backup directory not found: $src"
    exit 1
  fi

  log_info "Restoring backup from $src"

  cd "$src" || exit 1
  rsync -a --relative --no-owner --no-group . /

  log_succes "Restore completed."
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
