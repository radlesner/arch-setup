#! /usr/bin/env bash

# Exit Immediately if a command fails
set -o errexit

readonly REPO_DIR="$(dirname "$(readlink -m "${0}")")"
source "${REPO_DIR}/core.sh"

usage() {
cat << EOF

Usage: $0 [OPTION]...

OPTIONS:
  -p, --position      Picture display position    [left|right] (default is left)
  -s, --screen        Screen display variant(s)   [1080p|2k|4k] (default is 1080p)
  -l, --logo          Show a logo on picture      [default|system] (default: a mountain logo)
  -r, --remove        Remove/Uninstall theme      (default is all)
  -b, --boot          Install theme into '/boot/grub' or '/boot/grub2'
  -h, --help          Show this help

EOF
}

#######################################################
#   :::::: A R G U M E N T   H A N D L I N G ::::::   #
#######################################################

while [[ $# -gt 0 ]]; do
  PROG_ARGS+=("${1}")
  dialog='false'
  case "${1}" in
    -r|--remove)
      remove='true'
      shift
      ;;
    -b|--boot)
      install_boot='true'
      if [[ -d "/boot/grub" ]]; then
        GRUB_DIR="/boot/grub/themes"
      elif [[ -d "/boot/grub2" ]]; then
        GRUB_DIR="/boot/grub2/themes"
      fi
      shift
      ;;
    -p|--position)
      shift
      for position in "${@}"; do
        case "${position}" in
          left)
            positions+=("${POSITION_VARIANTS[0]}")
            shift
            ;;
          right)
            positions+=("${POSITION_VARIANTS[1]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized position variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -s|--screen)
      shift
      for screen in "${@}"; do
        case "${screen}" in
          1080p)
            screens+=("${SCREEN_VARIANTS[0]}")
            shift
            ;;
          2k)
            screens+=("${SCREEN_VARIANTS[1]}")
            shift
            ;;
          4k)
            screens+=("${SCREEN_VARIANTS[2]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized screen variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -l|--logo)
      shift
      for logo in "${@}"; do
        case "${logo}" in
          default)
            logoicon="Default"
            shift
            ;;
          system)
            logoicon="$(lsb_release -i | cut -d ' ' -f 2 | cut -d '	' -f 2)"
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized logo variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      prompt -e "ERROR: Unrecognized installation option '$1'."
      prompt -i "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

#############################
#   :::::: M A I N ::::::   #
#############################

# Show terminal user interface for better use
if [[ "${dialog:-}" == 'false' ]]; then
  if [[ "${remove:-}" != 'true' ]]; then
    for position in "${positions[@]-${POSITION_VARIANTS[0]}}"; do
      for screen in "${screens[@]-${SCREEN_VARIANTS[0]}}"; do
        install "${position}" "${screen}"
      done
    done
  elif [[ "${remove:-}" == 'true' ]]; then
    for position in "${positions[@]-${POSITION_VARIANTS[@]}}"; do
      for screen in "${screens[@]-${SCREEN_VARIANTS[@]}}"; do
        remove "${position}" "${screen}"
      done
    done
  fi
else
  dialog_installer
fi

exit 0
