#!/bin/bash
#
# Auto Arch Setup Script
# Version: 1.0.4
# Author: Radek Lesner (https://github.com/radlesner)
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

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}[!] This script option must be run as root.${RESET}"
    exit 1
  fi
}

install_grub() {
  root_check

  if ! mount | grep -q '/boot type vfat'; then
    echo "${RED}[!] /boot is not mounted or is not a vfat EFI partition!${RESET}"
    exit 1
  fi

  if [ -d /boot/EFI/GRUB ]; then
    echo "${BLUE}[i] GRUB seems to be already installed.${RESET}"
  else
    read -r -p "${YELLOW}[?] Do you want to install GRUB loader? [Y/n]: ${RESET}" confirm
    confirm=${confirm,,}
    if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
      pacman -Syu --noconfirm
      echo "${BLUE}[i] Installing grub packages...${RESET}"
      pacman -S --noconfirm --needed \
        grub \
        efibootmgr \
        dosfstools

      echo "${BLUE}[i] Installing GRUB...${RESET}"
      grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

      echo "${BLUE}[i] Configuring GRUB...${RESET}"
      sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
      grub-mkconfig -o /boot/grub/grub.cfg

      echo "${GREEN}[✓] GRUB installation complete${RESET}"
    else
      echo "${RED}[!] GRUB installation aborted!${RESET}"
      exit 0
    fi
  fi
}

remove_grub() {
  root_check

  read -r -p "${YELLOW}[?] Do you realy want remove GRUB bootloader? [N/y]: ${RESET}" confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    if [ -d /boot/EFI ]; then
      echo "${BLUE}[i] Deleting /boot/EFI...${RESET}"
      rm -rf /boot/EFI
    fi

    if [ -d /boot/grub ]; then
      echo "${BLUE}[i] Deleting /boot/grub...${RESET}"
      rm -rf /boot/grub
    fi
  fi
}

install_grub_theme() {
  root_check

  echo "${BLUE}[i] Select GRUB theme to install:${RESET}"
  echo "  1) Particle"
  echo "  2) Particle-circle"
  echo "  3) Matrix"
  echo "  4) Matrix-circle"
  echo "  5) Solara-grub2"
  echo "  0) Exit the script."
  read -r -p "${YELLOW}[?] Enter choice: ${RESET}" choice

  case "$choice" in
    1)
      echo "${BLUE}[i] Installing Particle GRUB theme...${RESET}"
      SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
      bash "$SCRIPT_DIR/environment-resources/grub-theme/Particle-grub-theme/install.sh"
      ;;
    2)
      echo "${BLUE}[i] Installing Particle GRUB theme...${RESET}"
      SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
      bash "$SCRIPT_DIR/environment-resources/grub-theme/Particle-circle-grub-theme/install.sh"
      ;;
    3)
      echo "${BLUE}[i] Installing Particle GRUB theme...${RESET}"
      SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
      bash "$SCRIPT_DIR/environment-resources/grub-theme/Matrix-circle-grub-theme/install.sh"
    ;;
    4)
      echo "${BLUE}[i] Installing Particle GRUB theme...${RESET}"
      SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
      bash "$SCRIPT_DIR/environment-resources/grub-theme/Matrix-circle-grub-theme/install.sh"
    ;;
    5)
      echo "${BLUE}[i] Installing Particle GRUB theme...${RESET}"
      SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
      bash "$SCRIPT_DIR/environment-resources/grub-theme/Solara-grub2-theme/install.sh"
    ;;
    0)
      echo "${BLUE}[i] Exiting the script.${RESET}"
      return
      ;;
    *)
      echo "${RED}[!] Invalid choice. Aborting.${RESET}"
      echo "${RED}[!] Use: --help options${RESET}"
      return
      ;;
  esac
}

setting_postinstall() {
  root_check

  echo "${BLUE}[i] Configuring locale...${RESET}"
  locale-gen
  localectl set-locale LANG=en_US.UTF-8
  echo "KEYMAP=pl" > /etc/vconsole.conf
  echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
  echo "FONT_MAP=8859-2" >> /etc/vconsole.conf
  echo "${GREEN}[✓] Locale configuration complete${RESET}"

  echo "${BLUE}[i] Configure timezone...${RESET}"
  ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
  hwclock --systohc
  echo "${GREEN}[✓] Timezone configuration complete${RESET}"

  echo "${BLUE}[i] Configure NTP clock...${RESET}"
  systemctl enable systemd-timesyncd.service
  timedatectl set-ntp true
  echo "${GREEN}[✓] NTP clock configuration complete${RESET}"

  echo "${BLUE}[i] Configuring hostname...${RESET}"
  read -r -p "${YELLOW}Enter hostname for this system: ${RESET}" HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    echo "${RED}[!] No hostname entered, using default: archlinux${RESET}"
    HOSTNAME="archlinux"
  fi
  echo "$HOSTNAME" > /etc/hostname
  echo "${GREEN}[✓] Hostname configuration complete${RESET}"

  echo "${BLUE}[i] Configuring pacman...${RESET}"
  sed -i 's/^#Color/Color/' /etc/pacman.conf
  sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
  sed -i 's/^#DownloadUser = alpm/DownloadUser = alpm/' /etc/pacman.conf

  echo "${BLUE}[i] Setting root password...${RESET}"
  passwd

  read -r -p "${YELLOW}[?] Do you want create the new user? [Y/n]: ${RESET}" confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    read -r -p "${YELLOW}[?] Enter username for the new user: ${RESET}" username
    if id "$username" &>/dev/null; then
      echo "${BLUE}[i] User $username already exists.${RESET}"
    else
      echo "${BLUE}[i] Creating new user $username...${RESET}"
      mkdir -p /home/$username
      useradd -M -d /home/$username/ -s /usr/bin/bash $username
      chown -R $username:$username /home/$username
      passwd $username

      echo "${BLUE}[i] Configuring new user $username...${RESET}"
      usermod -aG wheel,uucp $username
    fi
  fi

  install_base_packages
}

install_base_packages() {
  root_check

  echo "${BLUE}[i] Installing essential packages...${RESET}"
  pacman -S --noconfirm --needed \
    sudo \
    usbutils \
    btrfs-progs \
    networkmanager \
    openssh \
    nano \
    zsh \
    git \
    cmake \
    screen \
    which \
    wget \
    base-devel \
    cups \
    cups-filters \
    htop

  echo "${BLUE}[i] Enabling NetworkManager...${RESET}"
  systemctl enable NetworkManager

  echo "${BLUE}[i] Enabling CUPS service...${RESET}"
  sudo systemctl enable cups

  echo "${BLUE}[i] Configuring the /etc/sudoers file for the wheel group...${RESET}"
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  clear_cache

  echo "${GREEN}[✓] Base setup completed!${RESET}"
}

install_hamradio_packages() {
  check_yay_installed
  if [ $? -eq 0 ]; then
    echo "${BLUE}[i] Found yay, moving on to installing packages from AUR...${RESET}"
  else
    echo "${BLUE}[i] No yay found, starting yay install...${RESET}"
    install_yay
  fi

  yay -S --noconfirm --needed \
    cqrlog-bin \

  echo "${BLUE}[i] Copying 99.usb-serial.rules to /etc/udev/rules.d...${RESET}"
  sudo cp environment-resources/udev-rules/99.usb-serial.rules /etc/udev/rules.d

  echo "${BLUE}[i] Resfreshing udev rules...${RESET}"
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  echo "${GREEN}[✓] Setup udev rules completed!${RESET}"
}

install_virtualbox() {
  root_check

  echo
  echo "${BLUE}[i] Select VirtualBox installation method:${RESET}"
  echo "  1) Install from Arch repository"
  echo "  2) Install from official .run installer"
  read -r -p "${YELLOW}[?] Enter choice [1/2]: ${RESET}" choice

  ### REPOSITORY INSTALLER

  if [[ "$choice" == "1" ]]; then
      echo "${BLUE}[i] Installing VirtualBox from Arch repository...${RESET}"
      pacman -S --noconfirm --needed linux-headers virtualbox virtualbox-host-modules-arch

      echo "${BLUE}[i] Loading VirtualBox kernel modules...${RESET}"
      modprobe vboxdrv

      if lsmod | grep -q vboxdrv; then
          echo "${GREEN}[✓] VirtualBox modules loaded successfully.${RESET}"
      else
          echo "${RED}[!] VirtualBox modules failed to load. You may need to reboot.${RESET}"
      fi

      echo "${GREEN}[✓] VirtualBox successfully installed from repository.${RESET}"
      ask_reboot
      return 0
  fi

  if [[ "$choice" != "2" ]]; then
      echo "${RED}[!] Invalid selection. Installation aborted.${RESET}"
      return 1
  fi

  ### RUN FILE INSTALLER

  echo "${BLUE}[i] Checking virtualization support...${RESET}"
  if grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
      echo "${GREEN}[✓] CPU does support virtualization.${RESET}"
  else
      echo "${RED}[!] CPU does not support virtualization. Enable it in BIOS/UEFI. Installation aborted.${RESET}"
      exit 1
  fi

  if lsmod | grep -q 'kvm'; then
      echo "${BLUE}[i] KVM modules are active, disabling KVM...${RESET}"

      if [ ! -f /etc/modprobe.d/disable-kvm.conf ]; then
        touch /etc/modprobe.d/disable-kvm.conf
      fi

      echo "blacklist kvm" > /etc/modprobe.d/disable-kvm.conf

      cpu_vendor=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
      if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
          echo "blacklist kvm_intel" >> /etc/modprobe.d/disable-kvm.conf
      elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
          echo "blacklist kvm_amd" >> /etc/modprobe.d/disable-kvm.conf
      else
          echo "${RED}[!] Could not recognize processor manufacturer. Installation aborted.${RESET}"
          rm -f /etc/modprobe.d/disable-kvm.conf
          exit 1
      fi

      echo "${BLUE}[i] Regenerating initramfs images...${RESET}"
      mkinitcpio -P
  fi

  echo "${BLUE}[i] Installing linux-headers if needed...${RESET}"
  pacman -S --noconfirm --needed linux-headers

  echo "${BLUE}[i] Fetching latest VirtualBox version...${RESET}"
  latest_version=$(curl -s https://download.virtualbox.org/virtualbox/LATEST.TXT)

  if [ -z "$latest_version" ]; then
      echo "${RED}[!] Could not fetch latest version. Installation aborted.${RESET}"
      return 1
  fi

  echo "${BLUE}[i] Latest VirtualBox version: $latest_version${RESET}"
  url="https://download.virtualbox.org/virtualbox/${latest_version}/VirtualBox-${latest_version}-168469-Linux_amd64.run"

  echo "${BLUE}[i] Downloading VirtualBox installer...${RESET}"
  wget "$url" -O /tmp/virtualbox.run

  echo "${BLUE}[i] Making installer executable...${RESET}"
  chmod +x /tmp/virtualbox.run

  echo "${BLUE}[i] Running installer...${RESET}"
  /tmp/virtualbox.run

  echo "${BLUE}[i] Building VirtualBox kernel modules...${RESET}"
  if [ -x /sbin/vboxconfig ]; then
      /sbin/vboxconfig
  else
      echo "${RED}[!] vboxconfig not found, you may need to manually load modules.${RESET}"
  fi

  echo "${GREEN}[✓] VirtualBox successfully installed from official .run installer.${RESET}"
  ask_reboot
}


install_audio() {
  echo "${BLUE}[i] Installing audio packages...${RESET}"
  sudo pacman -S --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber

  echo "${BLUE}[i] PipeWire services will be activated upon DE login session.${RESET}"
  echo "${GREEN}[✓] Installing audio packages completed!${RESET}"
}

install_xfce() {
  pacman_update
  install_audio
  install_xorg "x11"

  echo "${BLUE}[i] Installing XFCE desktop environment...${RESET}"
  pacman -S --noconfirm --needed \
    xfce4 \
    xfce4-goodies \
    ristretto \
    thunar \
    thunar-archive-plugin \
    thunar-volman \
    file-roller \
    gvfs \
    thunderbird \
    libreoffice \
    galculator \
    xarchiver \
    gparted \
    pavucontrol \
    gnome-keyring \
    seahorse \
    blueman

  echo "${GREEN}[✓] XFCE installation completed! System restart required.${RESET}"
  clear_cache
  ask_reboot
}

install_plasma() {
  install_audio
  install_xorg "wayland"

  echo "${BLUE}[i] Installing KDE Plasma desktop environment...${RESET}"
  sudo pacman -S --noconfirm --needed \
    plasma-desktop \
    konsole \
    dolphin \
    mousepad \
    systemsettings \
    kinfocenter \
    kscreen \
    kde-cli-tools \
    kio \
    kio-extras \
    kwin \
    kwallet \
    kwallet-pam \
    plasma-workspace \
    plasma-pa \
    plasma-nm \
    gtk-engine-murrine \
    gtk2 \
    gtk3 \
    powerdevil \
    xdg-desktop-portal-kde \
    ffmpegthumbs \
    filelight \
    spectacle \
    ark \
    kde-gtk-config \
    sddm \
    zip \
    unzip \
    p7zip \
    unrar \
    gwenview \
    print-manager \
    kcalc \
    bluedevil \
    power-profiles-daemon

  echo "${BLUE}[i] Enabling sddm...${RESET}"
  sudo systemctl enable sddm

  echo "${BLUE}[i] Enabling bluetooth...${RESET}"
  sudo systemctl enable bluetooth

  echo "${GREEN}[✓] KDE Plasma installation completed! System restart required.${RESET}"

  clear_cache
  ask_reboot
}

install_hyprland() {
  install_audio
  install_xorg "wayland"

  echo "${BLUE}[i] Installing Hyprland (Wayland compositor)...${RESET}"
  sudo pacman -S --noconfirm --needed \
    hyprland \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal \
    xdg-utils \
    wl-clipboard \
    \
    hypridle \
    hyprpaper \
    swaylock \
    \
    waybar \
    mako \
    brightnessctl \
    \
    grim \
    slurp \
    \
    wofi \
    kitty \
    mousepad \
    \
    thunar \
    thunar-archive-plugin \
    thunar-media-tags-plugin \
    gvfs \
    gvfs-smb \
    gvfs-nfs \
    zip \
    unzip \
    unrar \
    p7zip \
    xarchiver \
    \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    \
    pavucontrol \
    \
    otf-font-awesome \
    ttf-nerd-fonts-symbols \
    gnome-themes-extra \
    lxappearance \
    gnome-keyring \
    \
    ly \
    \
    firefox \
    thunderbird \
    filezilla \
    \
    mpv \
    imv \
    libreoffice-fresh

  echo "${BLUE}[i] Enabling ly login manager...${RESET}"
  sudo systemctl enable ly.service

  echo "${BLUE}[i] Enabling bluetooth...${RESET}"
  sudo systemctl enable bluetooth

  echo "${BLUE}[i] Enabling audio...${RESET}"
  systemctl --user enable --now pipewire.service
  systemctl --user enable --now wireplumber.service

  echo "${BLUE}[i] Installing icons..."${RESET};
  mkdir -p ~/.icons
  tar -xf ./environment-resources/icons/01-Flat-Remix-Blue-20250709.tar.xz -C ~/.icons/
  gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'

  check_yay_installed
  if [ $? -eq 0 ]; then
    echo "${BLUE}[i] Found yay, moving on to installing packages from AUR...${RESET}"
  else
    echo "${BLUE}[i] No yay found, starting yay install...${RESET}"
    install_yay
  fi

  echo "${BLUE}[i] Installing AUR packages...${RESET}"
  yay -S --noconfirm --needed \
    neofetch \
    ookla-speedtest-bin \
    spotify \
    vscodium-bin

  echo "${GREEN}[✓] Hyprland environment installation completed!${RESET}"

  clear_cache
  hypr_copy_config


  ask_reboot
}

hypr_copy_config () {
  echo "${BLUE}[i] Select Hyprland config to copy:${RESET}"
  echo "  1) Config 01 for laptop"
  echo "  2) Config 02 fot desktop"
  echo "  0) Exit the script."
  read -r -p "${YELLOW}[?] Enter choice [1/2]: ${RESET}" choice

  case "$choice" in
    1)
      HYPR_CONFIG_OPTION="hyprland-config-01"
      ;;
    2)
      HYPR_CONFIG_OPTION="hyprland-config-02"
      ;;
    0)
      echo "${BLUE}[i] Exiting the script.${RESET}"
      return
      ;;
    *)
      echo "${RED}[!] Invalid choice. Aborting.${RESET}"
      echo "${RED}[!] Use: --help options${RESET}"
      return
      ;;
  esac

  read -r -p "${YELLOW}[?] Do you want to copy hyprland config to .config? [Y/n]${RESET}: " confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    COPY_FOLDERS=("hypr" "kitty" "waybar" "wofi" "mako")

    for cfg in "${COPY_FOLDERS[@]}"; do
        SRC="./environment-resources/$HYPR_CONFIG_OPTION/$cfg"

        if [ -d "$SRC" ]; then
            echo "${BLUE}[i] Copying $cfg config...${RESET}"
            cp -rf "$SRC" "$HOME/.config"
        fi
    done
  fi
}

install_xorg() {
  local mode=$1

  echo "${BLUE}[i] Installing X server packages for '$mode'...${RESET}"

case "$mode" in
  x11)
    sudo pacman -S --noconfirm --needed xorg xorg-xinit
    ;;
  wayland)
    sudo pacman -S --noconfirm --needed \
      wayland \
      wayland-protocols \
      xorg-xwayland
    ;;
  *)
    echo "${RED}[!] Unknown mode: $mode. Use 'x11' or 'wayland'.${RESET}"
    return 1
    ;;
esac

  echo "${GREEN}[✓] Xorg installation for '$mode' completed!${RESET}"
}

install_yay() {
  if ! command -v yay &>/dev/null; then
    echo "${BLUE}[i] Installing yay AUR helper...${RESET}"
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
  else
    echo "${GREEN}[✓] yay already installed.${RESET}"
  fi
}

check_yay_installed() {
  if ! command -v yay &>/dev/null; then
    return 1
  else
    return 0
  fi
}


install_fingerprint() {
  echo -e "\e[32m[i] Installing fingerprint login method...\e[0m"
  echo -e "\e[32m[i] Update repository...\e[0m"
  sudo pacman -Syu --noconfirm

  echo -e "\e[32m[i] Installing fprintd & pam...\e[0m"
  sudo pacman -S --noconfirm --needed \
    fprintd \
    pam

  echo -e "\e[32m[i] Scaning finger print, please scan your finger...\e[0m"
  sudo fprintd-enroll $(whoami)

  # sudo cp ./environment-resources/pam/ly                  /etc/pam.d/
  # sudo cp ./environment-resources/pam/swaylock            /etc/pam.d/
  # sudo cp ./environment-resources/pam/system-local-login  /etc/pam.d/
}

ask_reboot() {
  read -r -p "${YELLOW}[?] Do you want to restart system? [Y/n]: ${RESET}" confirm
  [[ "$confirm" =~ ^(n|no)$ ]] || reboot
}

clear_cache() {
  echo "${BLUE}[i] Clearing cache...${RESET}"
  sudo pacman -Sc
}

# -------------------------------------------------------- MAIN --------------------------------------------------------

force=false

for arg in "$@"; do
    if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        force=true
        break
    fi
done

case "$1" in
  --chroot-postinstall)
    setting_postinstall
    ;;
  --install-grub)
    if $force; then
      remove_grub
      install_grub
    else
      install_grub
    fi
    ;;
  --remove-grub)
    remove_grub
    ;;
  --install-grub-theme)
    install_grub_theme
    ;;
  --install-base)
    install_base_packages
    ;;
  --install-hamradio-setup)
    install_hamradio_packages
    ;;
  --install-xfce)
    install_xfce
    ;;
  --install-plasma)
    install_plasma
    ;;
  --install-hyprland)
    install_hyprland
    ;;
  --copy-hypr-config)
    hypr_copy_config
    ;;
  --install-yay)
    install_yay
    ;;
  --install-vbox)
    install_virtualbox
    ;;
  --install-fingerprint)
    install_fingerprint
    ;;
  --help)
    echo ""
    echo ">>> System installation options:"
    echo "    --chroot-postinstall     - Configure post-installation system settings"
    echo "    --install-base           - Install base packages and enable services"
    echo "    --install-grub           - Install GRUB bootloader (EFI)"
    echo "    --remove-grub            - Remove GRUB bootloader (EFI)"
    echo "    --install-grub-theme     - Install GRUB themes"
    echo "    --install-yay            - Install yay AUR helper"
    echo "    --install-vbox           - Install VirtualBox"
    echo "    --install-fingerprint    - Install fingerprint login option (Untested yet, not work with pam configuration)"
    echo "    --install-hamradio-setup - Install Ham Radio setup"
    echo ""
    echo ">>> Desktop environment installation options:"
    echo "    --install-xfce           - Install XFCE desktop environment"
    echo "    --install-plasma         - Install KDE Plasma desktop environment"
    echo "    --install-hyprland       - Install Hyprland Wayland compositor"
    echo "    --copy-hypr-config       - Copy custom Hyprland configuration files"
    echo ""
    echo ">>> Additional options:"
    echo "    -f, --force              - Force reinstall (e.g., overwrite existing GRUB installation)"
    echo ""
    ;;
  *)
    echo "Use: --help options"
    exit 1
    ;;
esac
