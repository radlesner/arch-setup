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

pacman_update() {
  pacman -Syu --noconfirm
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
      pacman_update
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

  read -p "[?] Do you want create the new user? [Y/n]" confirm
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

      echo "[i] Configuring new user $username..."
      usermod -aG wheel,uucp $username
    fi
  fi

  ask_reboot
}

install_base_packages() {
  root_check

  pacman_update
  echo "[i] Installing essential packages..."
  pacman -S --noconfirm --needed \
    sudo \
    btrfs-progs \
    networkmanager \
    openssh \
    nano \
    zsh \
    git \
    neofetch \
    screen \
    which \
    wget

  echo "[i] Enabling NetworkManager..."
  systemctl enable NetworkManager

  echo "[i] Configuring the /etc/sudoers file for the wheel group..."
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/pacman.conf

  clear_cache

  echo "[✓] Base setup completed!"
}

install_extra_packages() {
  root_check

  pacman_update
  echo "[i] Installing extra packages..."
  pacman -S --noconfirm --needed \
    base-devel \
    cups \
    cups-filters \
    firefox

  echo "[i] Enabling CUPS service..."
  systemctl enable cups

  echo "[✓] Installing extra packages completed!"
  clear_cache
}

install_virtualbox() {
  root_check

  echo "[i] Checking virtualization support..."
  if grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
      echo "[✓] CPU does support virtualization."
  else
      echo "[!] CPU does not support virtualization, try enable virtualization in BIOS. Installation aborted."
      exit 1
  fi

  if lsmod | grep -q 'kvm'; then
      echo "[i] KVM modules is active, disabling KVM..."

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
          echo "[!] Could not recognize processor manufacturer. Installation Virtualbox aborted"
          rm -rf /etc/modprobe.d/disable-kvm.conf
          exit 1
      fi
      echo "[i] Generating initramfs images..."
      mkinitcpio -P
  fi

  echo "[i] Installing linux-headers, otherwise skipping..."
  pacman -S --noconfirm --needed linux-headers

  echo "[i] Installing VirtualBox package..."
  echo "[i] Checking latest VirtualBox version..."

  latest_version=$(curl -s https://download.virtualbox.org/virtualbox/LATEST.TXT)

  if [ -z "$latest_version" ]; then
    echo "[!] Could not fetch latest version info."
    return 1
  fi

  echo "[i] Latest VirtualBox version: $latest_version"

  url="https://download.virtualbox.org/virtualbox/${latest_version}/VirtualBox-${latest_version}-168469-Linux_amd64.run"

  echo "[i] Downloading VirtualBox ${latest_version}..."
  wget "$url" -O /tmp/virtualbox.run

  echo "[i] Making installer executable..."
  chmod +x /tmp/virtualbox.run

  echo "[i] Installing VirtualBox..."
  /tmp/virtualbox.run

  echo "[i] Building VirtualBox kernel modules..."
  '/sbin/vboxconfig'

  echo "[✓] VirtualBox ${latest_version} installed!"
  ask_reboot
}

install_audio() {
  root_check

  echo "[i] Installing audio packages..."
  pacman -S --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber

  echo "[i] PipeWire services will be activated upon DE login session."
  echo "[✓] Installing audio packages completed!"
}

install_xfce() {
  root_check

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
  root_check

  pacman_update
  install_audio
  install_xorg "wayland"

  echo "[i] Installing KDE Plasma desktop environment..."
  pacman -S --noconfirm --needed \
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
  systemctl enable sddm

  echo "[i] Enabling bluetooth..."
  systemctl enable bluetooth

  echo "[✓] KDE Plasma installation completed! System restart required."

  clear_cache
  ask_reboot
}

install_hyprland() {
  root_check

  pacman_update
  install_audio
  install_xorg "wayland"

  echo "[i] Installing Hyprland (Wayland compositor)..."
  pacman -S --noconfirm --needed\
    hyprland \
    hypridle \
    hyprpaper \
    swaylock \
    wl-clipboard \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal \
    xdg-utils \
    waybar \
    ttf-font-awesome \
    ttf-nerd-fonts-symbols \
    brightnessctl \
    wofi \
    kitty \
    gnome-themes-extra \
    lxappearance \
    pcmanfm \
    xbindkeys xdotool \
    gvfs \
    gvfs-smb \
    zip unzip unrar p7zip xarchiver\
    gnome-keyring \
    network-manager-applet \
    bluez \
    bluez-utils \
    blueman \
    pavucontrol \
    grim \
    slurp \
    mako \
    ly

  echo "[i] Enabling ly login manager..."
  systemctl enable ly.service

  echo "[i] Enabling bluetooth..."
  systemctl enable bluetooth

  echo "[i] Configuring xbindkeys..."
  cat <<EOF >> /home/$USER/.xbindkeysrc
"xdotool key Alt+Left"
b:8
"xdotool key Alt+Right"
b:9
EOF

  echo "[✓] Hyprland environment installation completed!"

  clear_cache

  hypr_copy_config

  ask_reboot
}

hypr_copy_config () {
  read -p "[?] Do you want to copy hyprland config to .config? [Y/n]: " confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    COPY_FOLDERS=("hypr" "kitty" "waybar" "wofi" "mako")

    for cfg in "${COPY_FOLDERS[@]}"; do
        SRC="./hyprland-config/$cfg"

        if [ -d "$SRC" ]; then
            echo "[i] Copying $cfg config..."
            cp -rf "$SRC" "$HOME/.config"
        fi
    done
  fi
}


install_xorg() {
  root_check

  local mode=$1

  echo "[i] Installing X server packages for '$mode'..."

case "$mode" in
  x11)
    pacman -S --noconfirm --needed xorg xorg-xinit
    ;;
  wayland)
    pacman -S --noconfirm --needed \
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
  pacman -Sc
}

# -------------------------------------------------------- MAIN --------------------------------------------------------

case "$1" in
  postinstall)
    setting_postinstall
    ;;
  grub)
    install_grub
    ;;
  main)
    install_base_packages
    ;;
  extra)
    install_extra_packages
    ;;
  xfce)
    install_xfce
    ;;
  plasma)
    install_plasma
    ;;
  hyprland)
    install_hyprland
    ;;
  hypr-copy-config)
    hypr_copy_config
    ;;
  yay-install)
    install_yay
    ;;
  vbox)
   install_virtualbox
   ;;
  --help)
    echo "        postinstall      - configure postinstall system"
    echo "        grub             - install GRUB bootloader (EFI)"
    echo "        main             - install base packages and enable services"
    echo "        extra            - install optional packages (audio, printing)"
    echo "        yay-instal       - install yay package"
    echo "        vbox             - install VirtualBox"
    echo ""
    echo ">>> Dekstop enviroment options:"
    echo "        xfce             - install XFCE desktop"
    echo "        plasma           - install KDE Plasma desktop"
    echo "        hyprland         - install Hyprland desktop"
    echo "        hypr-copy-config - copy Hyprland config files"
    ;;
  *)
    echo "Use: --help options"
    exit 1
    ;;
esac
