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

list="backup_list"
backup_base="./backup"
date=$(date +%Y%m%d-%H%M)
backup_dir="$backup_base/$(whoami)-on-$(hostname)-backup-$date"

do_backup_local() {
  log_info "Starting backup to $backup_dir"
  mkdir -p "$backup_dir"

  if [ ! -f "$list" ]; then
    log_error "No list file: $list"
    exit 1
  fi

  while read -r item; do
    [[ -z "$item" || "$item" =~ ^# ]] && continue
      item_expanded=$(eval echo "$item")
      item_expanded=$(realpath -m "$item_expanded")

      if [ -e "$item_expanded" ]; then
        echo "--> Copying: $item_expanded"
        rsync -a --relative "$item_expanded" "$backup_dir"
      else
        echo "${color_yellow}--> File or directory not found: $item_expanded${color_reset}"
      fi
  done < "$list"

  log_succes "Backup completed: $backup_dir"
}

do_restore_local() {
  if [ -z "$1" ]; then
    log_error "You must provide a backup directory (e.g. $backup_base/$date)"
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
    echo "OPTIONS:"
    echo "    --backup-local                     - Creating a local disk backup"
    echo "    --restore-local <backup_directory> - Restoring a local backup"
    exit 1
    ;;
esac
