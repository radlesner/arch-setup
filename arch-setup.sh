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

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "[!] This script option must be run as root."
    exit 1
  fi
}

install_grub() {
  root_check

  if ! mount | grep -q '/boot type vfat'; then
    echo "[!] /boot is not mounted or is not a vfat EFI partition!"
    exit 1
  fi

  if [ -d /boot/EFI/GRUB ]; then
    echo "[i] GRUB seems to be already installed."
  else
    read -p "[?] Do you want to install GRUB loader? [Y/n]: " confirm
    confirm=${confirm,,}
    if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
      pacman -Syu --noconfirm
      echo "[i] Installing grub packages..."
      pacman -S --noconfirm --needed \
        grub \
        efibootmgr \
        dosfstools

      echo "[i] Installing GRUB..."
      grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

      echo "[i] Configuring GRUB..."
      sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
      grub-mkconfig -o /boot/grub/grub.cfg
    else
      echo "[!] GRUB installation aborted!"
      exit 0
    fi
  fi
}

setting_postinstall() {
  root_check

  echo "[i] Configuring locale..."
  locale-gen
  localectl set-locale LANG=en_US.UTF-8
  echo "KEYMAP=pl" > /etc/vconsole.conf
  echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
  echo "FONT_MAP=8859-2" >> /etc/vconsole.conf
  echo "[✓] Locale configuration complete"

  echo "[i] Configure timezone..."
  ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
  hwclock --systohc
  echo "[✓] Timezone configuration complete"

  echo "[i] Configuring hostname..."
  read -rp "Enter hostname for this system: " HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    echo "[!] No hostname entered, using default: archlinux"
    HOSTNAME="archlinux"
  fi
  echo "$HOSTNAME" > /etc/hostname
  echo "[✓] Hostname configuration complete"

  echo "[i] Configuring pacman..."
  sed -i 's/^#Color/Color/' /etc/pacman.conf
  sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
  sed -i 's/^#DownloadUser = alpm/DownloadUser = alpm/' /etc/pacman.conf

  echo "[i] Setting root password..."
  passwd

  read -p "[?] Do you want create the new user? [Y/n]:" confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    read -p "[?] Enter username for the new user: " username
    if id "$username" &>/dev/null; then
      echo "[i] User $username already exists."
    else
      echo "[i] Creating new user $username..."
      mkdir -p /home/$username
      useradd -M -d /home/$username/ -s /usr/bin/bash $username
      chown -R $username:$username /home/$username
      passwd $username

      echo "[i] Configuring new user $username..."
      usermod -aG wheel,uucp $username
    fi
  fi

  install_base_packages
}

install_base_packages() {
  root_check


  echo "[i] Installing essential packages..."
  pacman -S --noconfirm --needed \
    sudo \
    usbutils \
    btrfs-progs \
    networkmanager \
    openssh \
    nano \
    zsh \
    git \
    screen \
    which \
    wget \
    base-devel \
    cups \
    cups-filters \

  echo "[i] Enabling NetworkManager..."
  systemctl enable NetworkManager

  echo "[i] Enabling CUPS service..."
  sudo systemctl enable cups

  echo "[i] Configuring the /etc/sudoers file for the wheel group..."
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  clear_cache

  echo "[✓] Base setup completed!"
}

install_virtualbox() {
  root_check

  echo
  echo "[i] Select VirtualBox installation method:"
  echo "  1) Install from Arch repository"
  echo "  2) Install from official .run installer"
  read -rp "[?] Enter choice [1/2]: " choice

  ### REPOSITORY INSTALLER

  if [[ "$choice" == "1" ]]; then
      echo "[i] Installing VirtualBox from Arch repository..."
      pacman -S --noconfirm --needed linux-headers virtualbox virtualbox-host-modules-arch

      echo "[i] Loading VirtualBox kernel modules..."
      modprobe vboxdrv

      if lsmod | grep -q vboxdrv; then
          echo "[✓] VirtualBox modules loaded successfully."
      else
          echo "[!] VirtualBox modules failed to load. You may need to reboot."
      fi

      echo "[✓] VirtualBox successfully installed from repository."
      ask_reboot
      return 0
  fi

  if [[ "$choice" != "2" ]]; then
      echo "[!] Invalid selection. Installation aborted."
      return 1
  fi

  ### RUN FILE INSTALLER

  echo "[i] Checking virtualization support..."
  if grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
      echo "[✓] CPU does support virtualization."
  else
      echo "[!] CPU does not support virtualization. Enable it in BIOS/UEFI. Installation aborted."
      exit 1
  fi

  if lsmod | grep -q 'kvm'; then
      echo "[i] KVM modules are active, disabling KVM..."

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
          echo "[!] Could not recognize processor manufacturer. Installation aborted."
          rm -f /etc/modprobe.d/disable-kvm.conf
          exit 1
      fi

      echo "[i] Regenerating initramfs images..."
      mkinitcpio -P
  fi

  echo "[i] Installing linux-headers if needed..."
  pacman -S --noconfirm --needed linux-headers

  echo "[i] Fetching latest VirtualBox version..."
  latest_version=$(curl -s https://download.virtualbox.org/virtualbox/LATEST.TXT)

  if [ -z "$latest_version" ]; then
      echo "[!] Could not fetch latest version. Installation aborted."
      return 1
  fi

  echo "[i] Latest VirtualBox version: $latest_version"
  url="https://download.virtualbox.org/virtualbox/${latest_version}/VirtualBox-${latest_version}-168469-Linux_amd64.run"

  echo "[i] Downloading VirtualBox installer..."
  wget "$url" -O /tmp/virtualbox.run

  echo "[i] Making installer executable..."
  chmod +x /tmp/virtualbox.run

  echo "[i] Running installer..."
  /tmp/virtualbox.run

  echo "[i] Building VirtualBox kernel modules..."
  if [ -x /sbin/vboxconfig ]; then
      /sbin/vboxconfig
  else
      echo "[!] vboxconfig not found, you may need to manually load modules."
  fi

  echo "[✓] VirtualBox successfully installed from official .run installer."
  ask_reboot
}


install_audio() {
  echo "[i] Installing audio packages..."
  sudo pacman -S --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber

  echo "[i] PipeWire services will be activated upon DE login session."
  echo "[✓] Installing audio packages completed!"
}

install_xfce() {
  pacman_update
  install_audio
  install_xorg "x11"

  echo "[i] Installing XFCE desktop environment..."
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

  echo "[✓] XFCE installation completed! System restart required."
  clear_cache
  ask_reboot
}

install_plasma() {
  install_audio
  install_xorg "wayland"

  echo "[i] Installing KDE Plasma desktop environment..."
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

  echo "[i] Enabling sddm..."
  sudo systemctl enable sddm

  echo "[i] Enabling bluetooth..."
  sudo systemctl enable bluetooth

  echo "[✓] KDE Plasma installation completed! System restart required."

  clear_cache
  ask_reboot
}

install_hyprland() {
  install_audio
  install_xorg "wayland"

  echo "[i] Installing Hyprland (Wayland compositor)..."
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
    ttf-font-awesome \
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

  echo "[i] Enabling ly login manager..."
  sudo systemctl enable ly.service

  echo "[i] Enabling bluetooth..."
  sudo systemctl enable bluetooth

  echo "[i] Enabling audio..."
  systemctl --user enable --now pipewire.service
  systemctl --user enable --now wireplumber.service

  echo "[i] Installing icons...";
  tar -xf ./environment-resources/icons/01-Flat-Remix-Blue-20250709.tar.xz -C ~/.icons/
  gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'

  echo "[✓] Hyprland environment installation completed!"

  clear_cache

  hypr_copy_config

  ask_reboot
}

hypr_copy_config () {
  echo "[i] Select Hyprland config to copy:"
  echo "  1) Laptop"
  echo "  2) Desktop"
  read -rp "[?] Enter choice [1/2]: " choice

  case "$choice" in
    1)
      HYPR_CONFIG_OPTION="hyprland-config-01"
      ;;
    2)
      HYPR_CONFIG_OPTION="hyprland-config-02"
      ;;
    *)
      echo "[!] Invalid choice. Aborting."
      ;;
  esac

  read -p "[?] Do you want to copy hyprland config to .config? [Y/n]: " confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    COPY_FOLDERS=("hypr" "kitty" "waybar" "wofi" "mako")

    for cfg in "${COPY_FOLDERS[@]}"; do
        SRC="./environment-resources/$HYPR_CONFIG_OPTION/$cfg"

        if [ -d "$SRC" ]; then
            echo "[i] Copying $cfg config..."
            cp -rf "$SRC" "$HOME/.config"
        fi
    done
  fi
}


install_xorg() {
  local mode=$1

  echo "[i] Installing X server packages for '$mode'..."

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
    echo "[!] Unknown mode: $mode. Use 'x11' or 'wayland'."
    return 1
    ;;
esac

  echo "[✓] Xorg installation for '$mode' completed!"
}

install_yay() {
  if ! command -v yay &>/dev/null; then
    echo "[i] Installing yay AUR helper..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
  else
    echo "[✓] yay already installed."
  fi
}

ask_reboot() {
  read -p "[?] Do you want to restart system? [Y/n]: " confirm
  [[ "$confirm" =~ ^(n|no)$ ]] || reboot
}

clear_cache() {
  echo "[i] Clearing cache..."
  sudo pacman -Sc
}

# -------------------------------------------------------- MAIN --------------------------------------------------------

case "$1" in
  --chroot-postinstall)
    setting_postinstall
    ;;
  --install-grub)
    install_grub
    ;;
  --install-base)
    install_base_packages
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
  --help)
    echo ""
    echo ">>> System installation options:"
    echo "    --chroot-postinstall    - Configure post-installation system settings"
    echo "    --install-base          - Install base packages and enable services"
    echo "    --install-grub          - Install GRUB bootloader (EFI)"
    echo "    --install-yay           - Install yay AUR helper"
    echo "    --install-vbox          - Install VirtualBox"
    echo ""
    echo ">>> Desktop environment installation options:"
    echo "    --install-xfce          - Install XFCE desktop environment"
    echo "    --install-plasma        - Install KDE Plasma desktop environment"
    echo "    --install-hyprland      - Install Hyprland Wayland compositor"
    echo "    --copy-hypr-config      - Copy custom Hyprland configuration files"
    echo ""
    ;;
  *)
    echo "Use: --help options"
    exit 1
    ;;
esac
