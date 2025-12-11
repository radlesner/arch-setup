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

log_info() { echo -e "${BLUE}[i] $1${RESET} "; }
log_error() { echo -e "${RED}[!] $1${RESET} "; }
log_qa() { printf "${YELLOW}[?] %s${RESET} " "$1"; }
log_succes() { echo -e "${GREEN}[✓] $1${RESET}"; }

root_check() {
  if [ "$(id -u)" -ne 0 ]; then
    log_error "This script option must be run as root."
    exit 1
  fi
}

install_from_archinstall() (
  local user_config="environment-resources/archinstall-config/user_configuration.json"
  local user_creds="environment-resources/archinstall-config/user_credentials.json"

  archinstall --config $user_config --creds $user_creds
)

partition_disk() {
  root_check

  DISK="$1"

  log_info "Creating a new GPT table on... $DISK"

  parted -s "$DISK" mklabel gpt

  log_info "Creating the EFI partition (512MiB)..."
  parted -s "$DISK" --align optimal mkpart ESP fat32 1MiB 513MiB
  parted -s "$DISK" set 1 esp on

  log_info "Creating the root partition (rest of the disk, Btrfs)..."
  parted -s "$DISK" --align optimal mkpart primary btrfs 513MiB 100%

  log_info "Setting correct partition type GUIDs..."
  sgdisk --typecode=1:ef00 "$DISK"                                 # EFI System Partition tyoe
  sgdisk --typecode=2:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 "$DISK" # Linux root (x86_64) type

  if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then
      P1="${DISK}p1"
      P2="${DISK}p2"
  else
      P1="${DISK}1"
      P2="${DISK}2"
  fi

  ROOTFS_PARTITION=$P2

  log_info "Formatting EFI... ($P1)"
  mkfs.fat -F32 "$P1"

  log_info "Formatting Btrfs... ($P2)"
  mkfs.btrfs -f "$P2"

  log_info "Creating Btrfs subvolumes..."
  mount "$P2" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@root
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@.snapshots
  umount /mnt

  log_info "Mounting subvolumes..."
  mount -o subvol=@ "$P2" /mnt
  mkdir -p /mnt/{root,home,.snapshots,boot}
  mount -o subvol=@root "$P2" /mnt/root
  mount -o subvol=@home "$P2" /mnt/home
  mount -o subvol=@.snapshots "$P2" /mnt/.snapshots
  mount "$P1" /mnt/boot

  log_succes "Done! The $DISK disk has been prepared and mounted to /mnt"
  log_info "Now run: genfstab -U /mnt >> /mnt/etc/fstab"
}

install_pacstrap() {
  pacstrap -K /mnt base linux linux-firmware
}

generate_fstab() {
  genfstab -U /mnt >> /mnt/etc/fstab
}

install_systemd_boot() {
  local DISK="$1"

  log_info "Installing systemd-boot..."
  bootctl install

  log_info "Creating loader.conf..."
  cat <<EOF > /boot/loader/loader.conf
timeout 1
EOF

  log_info "Creating boot entries..."
  ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$DISK")
  DATE=$(date +%Y-%m-%d_%H-%M-%S)
  ENTRY_DIR="/boot/loader/entries"

  mkdir -p "$ENTRY_DIR"

  cat <<EOF > "$ENTRY_DIR/${DATE}_linux.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$ROOT_PARTUUID rootflags=subvol=@ rw rootfstype=btrfs
EOF

  cat <<EOF > "$ENTRY_DIR/${DATE}_linux-fallback.conf"
title   Arch Linux (linux-fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=PARTUUID=$ROOT_PARTUUID rootflags=subvol=@ rw rootfstype=btrfs
EOF

  log_succes "systemd-boot has been installed and boot entries created"
}

install_grub() {
  root_check

  if ! mount | grep -q '/boot type vfat'; then
    log_error "/boot is not mounted or is not a vfat EFI partition!"
    exit 1
  fi

  if [ -d /boot/EFI/GRUB ]; then
    log_info "[i] GRUB seems to be already installed."
  else
    log_qa "Do you want to install GRUB loader? [Y/n]:"
    read -r confirm
    confirm=${confirm,,}
    if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
      log_info "Installing grub packages..."
      pacman -S --noconfirm --needed \
        grub \
        efibootmgr \
        dosfstools

      log_info "Installing GRUB..."
      grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

      log_info "Configuring GRUB..."
      sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
      grub-mkconfig -o /boot/grub/grub.cfg

      log_succes "GRUB installation complete"
    else
      log_error "GRUB installation aborted!"
      exit 0
    fi
  fi
}

remove_grub() {
  root_check

  log_qa "Do you realy want remove GRUB bootloader? [N/y]:"
  read -r confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    if [ -d /boot/EFI ]; then
      log_info "Deleting /boot/EFI..."
      rm -rf /boot/EFI
    fi

    if [ -d /boot/grub ]; then
      log_info "Deleting /boot/grub..."
      rm -rf /boot/grub
    fi
  fi
}

chroot_postinstall() {
  root_check

  log_info "Configuring locale..."
  locale-gen
  localectl set-locale LANG=en_US.UTF-8
  echo "KEYMAP=pl" > /etc/vconsole.conf
  echo "FONT=Lat2-Terminus16" >> /etc/vconsole.conf
  echo "FONT_MAP=8859-2" >> /etc/vconsole.conf
  log_succes "Locale configuration complete"

  log_info "Configure timezone..."
  ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
  hwclock --systohc
  log_succes "Timezone configuration complete"

  log_info "Configure NTP clock..."
  mkdir -p /etc/systemd/system/multi-user.target.wants
  ln -sf /usr/lib/systemd/system/systemd-timesyncd.service \
         /etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service
  timedatectl set-ntp true
  log_succes "NTP clock configuration complete"

  log_info "Configuring hostname..."
  log_qa "Enter a new hostname for this system:"
  read -r HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    log_error "No hostname entered, using default: archlinux"
    HOSTNAME="archlinux"
  fi
  echo "$HOSTNAME" > /etc/hostname
  log_succes "Hostname configuration complete"

  log_info "Configuring pacman..."
  sed -i 's/^#Color/Color/' /etc/pacman.conf
  sed -i 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
  sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
  sed -i 's/^#DownloadUser = alpm/DownloadUser = alpm/' /etc/pacman.conf

  log_info "Setting root password..."
  passwd

  log_qa "Do you want create the new user? [Y/n]:"
  read -r confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    log_qa "Enter username for the new user:"
    read -r username
    if id "$username" &>/dev/null; then
      log_info "User $username already exists."
    else
      log_info "Creating new user $username..."
      mkdir -p /home/$username
      useradd -M -d /home/$username/ -s /usr/bin/bash $username
      chown -R $username:$username /home/$username
      passwd $username

      log_info "Configuring new user $username..."
      usermod -aG wheel,uucp $username

      log_info "Copying arch-setup to the $username home folder for later desktop environment installation..."
      cp -r /root/arch-setup /home/$username/
      chown -R $username:$username /home/$username/arch-setup
    fi
  fi

  configure_mirrors
  pacman -Syu --noconfirm
  install_base_packages
}

configure_mirrors() {
  log_info "Configuring full mirrorlist (Germany + Poland)..."

  MIRRORS=(
    # Germany
    "http://ftp.tu-chemnitz.de/pub/linux/archlinux/\$repo/os/\$arch"
    "http://ftp.hosteurope.de/mirror/ftp.archlinux.org/\$repo/os/\$arch"
    "http://ftp.gwdg.de/pub/linux/archlinux/\$repo/os/\$arch"
    "http://ftp.uni-kl.de/pub/linux/archlinux/\$repo/os/\$arch"
    "http://ftp.uni-bayreuth.de/linux/archlinux/\$repo/os/\$arch"
    "http://ftp-stud.hs-esslingen.de/pub/Mirrors/archlinux/\$repo/os/\$arch"
    "http://ftp.spline.inf.fu-berlin.de/mirrors/archlinux/\$repo/os/\$arch"
    "https://ftp.spline.inf.fu-berlin.de/mirrors/archlinux/\$repo/os/\$arch"
    "http://mirror.selfnet.de/archlinux/\$repo/os/\$arch"
    "https://mirror.selfnet.de/archlinux/\$repo/os/\$arch"
    "http://ftp.halifax.rwth-aachen.de/archlinux/\$repo/os/\$arch"
    "https://ftp.halifax.rwth-aachen.de/archlinux/\$repo/os/\$arch"
    "http://artfiles.org/archlinux.org/\$repo/os/\$arch"
    "http://mirror.fra10.de.leaseweb.net/archlinux/\$repo/os/\$arch"
    "https://mirror.fra10.de.leaseweb.net/archlinux/\$repo/os/\$arch"
    "http://mirrors.n-ix.net/archlinux/\$repo/os/\$arch"
    "https://mirrors.n-ix.net/archlinux/\$repo/os/\$arch"
    "http://mirror.netcologne.de/archlinux/\$repo/os/\$arch"
    "https://mirror.netcologne.de/archlinux/\$repo/os/\$arch"
    "http://linux.rz.rub.de/archlinux/\$repo/os/\$arch"
    "http://ftp.fau.de/archlinux/\$repo/os/\$arch"
    "https://ftp.fau.de/archlinux/\$repo/os/\$arch"
    "http://mirror.23m.com/archlinux/\$repo/os/\$arch"
    "https://mirror.23m.com/archlinux/\$repo/os/\$arch"
    "http://mirror.metalgamer.eu/archlinux/\$repo/os/\$arch"
    "https://mirror.metalgamer.eu/archlinux/\$repo/os/\$arch"
    "http://mirrors.niyawe.de/archlinux/\$repo/os/\$arch"
    "https://mirrors.niyawe.de/archlinux/\$repo/os/\$arch"
    "http://ftp.uni-hannover.de/archlinux/\$repo/os/\$arch"
    "https://mirror.pseudoform.org/\$repo/os/\$arch"
    "http://arch.jensgutermuth.de/\$repo/os/\$arch"
    "https://arch.jensgutermuth.de/\$repo/os/\$arch"
    "http://mirror.ubrco.de/archlinux/\$repo/os/\$arch"
    "https://mirror.ubrco.de/archlinux/\$repo/os/\$arch"
    "http://archlinux.mirror.iphh.net/\$repo/os/\$arch"
    "http://archlinux.thaller.ws/\$repo/os/\$arch"
    "https://archlinux.thaller.ws/\$repo/os/\$arch"
    "http://de.mirrors.cicku.me/archlinux/\$repo/os/\$arch"
    "https://de.mirrors.cicku.me/archlinux/\$repo/os/\$arch"
    "https://mirror.bethselamin.de/\$repo/os/\$arch"
    "http://packages.oth-regensburg.de/archlinux/\$repo/os/\$arch"
    "https://packages.oth-regensburg.de/archlinux/\$repo/os/\$arch"
    "https://dist-mirror.fem.tu-ilmenau.de/archlinux/\$repo/os/\$arch"
    "https://arch.unixpeople.org/\$repo/os/\$arch"
    "http://mirror.wtnet.de/archlinux/\$repo/os/\$arch"
    "https://mirror.wtnet.de/archlinux/\$repo/os/\$arch"
    "http://arch.phinau.de/\$repo/os/\$arch"
    "https://arch.phinau.de/\$repo/os/\$arch"
    "https://mirror.dogado.de/archlinux/\$repo/os/\$arch"
    "http://mirror.clientvps.com/archlinux/\$repo/os/\$arch"
    "https://mirror.clientvps.com/archlinux/\$repo/os/\$arch"
    "https://pkg.fef.moe/archlinux/\$repo/os/\$arch"
    "http://ftp.agdsn.de/pub/mirrors/archlinux/\$repo/os/\$arch"
    "https://ftp.agdsn.de/pub/mirrors/archlinux/\$repo/os/\$arch"
    "http://mirrors.xtom.de/archlinux/\$repo/os/\$arch"
    "https://mirrors.xtom.de/archlinux/\$repo/os/\$arch"
    "http://mirror.moson.org/arch/\$repo/os/\$arch"
    "https://mirror.moson.org/arch/\$repo/os/\$arch"
    "http://mirror.pagenotfound.de/archlinux/\$repo/os/\$arch"
    "https://mirror.pagenotfound.de/archlinux/\$repo/os/\$arch"
    "https://de.arch.mirror.kescher.at/\$repo/os/\$arch"
    "http://mirrors.janbruckner.de/archlinux/\$repo/os/\$arch"
    "https://mirrors.janbruckner.de/archlinux/\$repo/os/\$arch"
    "http://mirror.informatik.tu-freiberg.de/arch/\$repo/os/\$arch"
    "https://mirror.informatik.tu-freiberg.de/arch/\$repo/os/\$arch"
    "https://berlin.mirror.pkgbuild.com/\$repo/os/\$arch"
    "http://mirror.cmt.de/archlinux/\$repo/os/\$arch"
    "https://mirror.cmt.de/archlinux/\$repo/os/\$arch"
    "http://mirror.sunred.org/archlinux/\$repo/os/\$arch"
    "https://mirror.sunred.org/archlinux/\$repo/os/\$arch"
    "http://mirror.lcarilla.de/archlinux/\$repo/os/\$arch"
    "https://mirror.lcarilla.de/archlinux/\$repo/os/\$arch"
    "https://archlinux.richard-neumann.de/\$repo/os/\$arch"
    "http://mirror.hugo-betrugo.de/archlinux/\$repo/os/\$arch"
    "https://mirror.hugo-betrugo.de/archlinux/\$repo/os/\$arch"
    "https://arch.kurdy.org/\$repo/os/\$arch"
    "http://de.arch.niranjan.co/\$repo/os/\$arch"
    "https://de.arch.niranjan.co/\$repo/os/\$arch"
    "https://files.hadiko.de/pub/dists/arch/\$repo/os/\$arch"
    "https://de-nue.soulharsh007.dev/archlinux/\$repo/os/\$arch"
    "https://de.repo.c48.uk/arch/\$repo/os/\$arch"
    "http://mirror.as20647.net/archlinux/\$repo/os/\$arch"
    "http://mirror.ipb.de/archlinux/\$repo/os/\$arch"
    "https://mirror.as20647.net/archlinux/\$repo/os/\$arch"
    "https://mirror.ipb.de/archlinux/\$repo/os/\$arch"
    "http://mirrors.aminvakil.com/archlinux/\$repo/os/\$arch"
    "https://mirrors.aminvakil.com/archlinux/\$repo/os/\$arch"
    "http://mirrors.purring.online/arch/\$repo/os/\$arch"
    "https://mirrors.purring.online/arch/\$repo/os/\$arch"
    "http://arch.owochle.app/\$repo/os/\$arch"
    "https://arch.owochle.app/\$repo/os/\$arch"
    "https://mirror.thereisno.page/archlinux/\$repo/os/\$arch"
    "http://arch.mirror.cloud.thatcyberlynx.de/\$repo/os/\$arch"
    "https://arch.mirror.cloud.thatcyberlynx.de/\$repo/os/\$arch"

    # Poland
    "http://arch.midov.pl/arch/\$repo/os/\$arch"
    "https://arch.midov.pl/arch/\$repo/os/\$arch"
    "http://ftp.icm.edu.pl/pub/Linux/dist/archlinux/\$repo/os/\$arch"
    "https://ftp.icm.edu.pl/pub/Linux/dist/archlinux/\$repo/os/\$arch"
    "http://mirror.juniorjpdj.pl/archlinux/\$repo/os/\$arch"
    "https://mirror.juniorjpdj.pl/archlinux/\$repo/os/\$arch"
    "http://ftp.psnc.pl/linux/archlinux/\$repo/os/\$arch"
    "https://ftp.psnc.pl/linux/archlinux/\$repo/os/\$arch"
    "http://arch.sakamoto.pl/\$repo/os/\$arch"
    "https://arch.sakamoto.pl/\$repo/os/\$arch"
    "https://mirror.przekichane.pl/archlinux/\$repo/os/\$arch"
  )

  mkdir -p /mnt/etc/pacman.d
  : > /mnt/etc/pacman.d/mirrorlist  # clear file

  for mirror in "${MIRRORS[@]}"; do
    echo "Server = $mirror" >> /mnt/etc/pacman.d/mirrorlist
  done

  log_succes "Mirrorlist configured with all Germany + Poland mirrors"
}

install_base_packages() {
  root_check

  log_info "Installing essential packages..."
  pacman -S --noconfirm --needed \
    sudo \
    usbutils \
    nano \
    zsh \
    git \
    cmake \
    screen \
    which \
    wget \
    htop \
    base-devel \
    \
    networkmanager \
    inetutils \
    openssh \
    \
    cups \
    cups-filters \
    \
    btrfs-progs \
    exfatprogs \
    ntfs-3g \
    dosfstools \
    cdrtools

  log_info "Enabling NetworkManager..."
  mkdir -p /etc/systemd/system/multi-user.target.wants
  ln -sf /usr/lib/systemd/system/NetworkManager.service \
         /etc/systemd/system/multi-user.target.wants/NetworkManager.service

  log_info "Enabling CUPS service..."
  ln -sf /usr/lib/systemd/system/cups.service \
         /etc/systemd/system/multi-user.target.wants/cups.service

  log_info "Configuring the /etc/sudoers file for the wheel group..."
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  log_succes "Base setup completed!"
}

install_hamradio_packages() {
  install_yay

  yay -S --removemake --noconfirm --needed \
    cqrlog-bin \
    wsjtx-improved \
    adif-multitool \
    chirp-next

  log_info "Copying 99.usb-serial.rules to /etc/udev/rules.d..."
  sudo cp environment-resources/udev-rules/99.usb-serial.rules /etc/udev/rules.d

  log_info "Resfreshing udev rules..."
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  log_succes "Setup udev rules completed!"
}

install_virtualbox() {
  root_check

  log_info "Select VirtualBox installation method:"
  echo "  1) Install from Arch repository"
  echo "  2) Install from official .run installer"
  log_qa "Enter choice [1/2]:"
  read -r choice

  ### REPOSITORY INSTALLER

  if [[ "$choice" == "1" ]]; then
      log_info "Installing VirtualBox from Arch repository..."
      pacman -S --noconfirm --needed linux-headers virtualbox virtualbox-host-modules-arch

      log_info "Loading VirtualBox kernel modules..."
      modprobe vboxdrv

      if lsmod | grep -q vboxdrv; then
          log_succes "VirtualBox modules loaded successfully."
      else
          log_error "VirtualBox modules failed to load. You may need to reboot."
      fi

      log_succes "VirtualBox successfully installed from repository."
      ask_reboot
      return 0
  fi

  if [[ "$choice" != "2" ]]; then
      log_error "Invalid selection. Installation aborted."
      return 1
  fi

  ### RUN FILE INSTALLER

  log_info "Checking virtualization support..."
  if grep -E '(vmx|svm)' /proc/cpuinfo > /dev/null; then
      log_succes "CPU does support virtualization."
  else
      log_error "CPU does not support virtualization. Enable it in BIOS/UEFI. Installation aborted."
      exit 1
  fi

  if lsmod | grep -q 'kvm'; then
      log_info "KVM modules are active, disabling KVM..."

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
          log_error "Could not recognize processor manufacturer. Installation aborted."
          rm -f /etc/modprobe.d/disable-kvm.conf
          exit 1
      fi

      log_info "Regenerating initramfs images..."
      mkinitcpio -P
  fi

  log_info "Installing linux-headers if needed..."
  pacman -S --noconfirm --needed linux-headers

  log_info "Fetching latest VirtualBox version..."
  latest_version=$(curl -s https://download.virtualbox.org/virtualbox/LATEST.TXT)

  if [ -z "$latest_version" ]; then
      log_error "Could not fetch latest version. Installation aborted."
      return 1
  fi

  log_info "Latest VirtualBox version: $latest_version"
  url="https://download.virtualbox.org/virtualbox/${latest_version}/VirtualBox-${latest_version}-168469-Linux_amd64.run"

  log_info "Downloading VirtualBox installer..."
  wget "$url" -O /tmp/virtualbox.run

  log_info "Making installer executable..."
  chmod +x /tmp/virtualbox.run

  log_info "Running installer..."
  /tmp/virtualbox.run

  log_info "Building VirtualBox kernel modules..."
  if [ -x /sbin/vboxconfig ]; then
      /sbin/vboxconfig
  else
      log_error "vboxconfig not found, you may need to manually load modules."
  fi

  log_succes "VirtualBox successfully installed from official .run installer."
  ask_reboot
}


install_audio() {
  log_info "Installing audio packages..."
  sudo pacman -S --needed --noconfirm \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber

  log_info "PipeWire services will be activated upon DE login session."
  log_succes "Installing audio packages completed!"
}

install_xfce() {
  install_audio
  install_xorg "x11"

  log_info "Installing XFCE desktop environment..."
  sudo pacman -S --noconfirm --needed \
    xfce4 \
    xfce4-goodies \
    lightdm \
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

  log_info "Enabling lightdm login manager..."
  systemctl enable lightdm.service

  log_succes "XFCE installation completed! System restart required."
  ask_reboot
}

install_plasma() {
  install_audio
  install_xorg "wayland"

  log_info "Installing KDE Plasma desktop environment..."
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

  log_info "Enabling sddm..."
  sudo systemctl enable sddm

  log_info "Enabling bluetooth..."
  sudo systemctl enable bluetooth

  log_succes "KDE Plasma installation completed! System restart required."
  ask_reboot
}

install_hyprland() {
  install_audio
  install_xorg "wayland"

  log_info "Installing Hyprland (Wayland compositor)..."
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
    gnome-disk-utility \
    \
    gvfs \
    gvfs-smb \
    gvfs-nfs \
    gvfs-mtp \
    gvfs-gphoto2 \
    android-udev \
    \
    zip \
    unzip \
    unrar \
    p7zip \
    xarchiver \
    rsync \
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
    polkit-gnome \
    gnome-keyring \
    seahorse \
    gparted \
    \
    ly \
    \
    firefox \
    thunderbird \
    filezilla \
    \
    mpv \
    imv \
    libreoffice-fresh \
    imagemagick

  log_info "Enabling ly login manager..."
  sudo systemctl enable ly.service

  log_info "Enabling bluetooth..."
  sudo systemctl enable bluetooth

  log_info "Enabling audio..."
  systemctl --user enable --now pipewire.service
  systemctl --user enable --now wireplumber.service

  log_info "Installing icons...";
  mkdir -p ~/.icons
  tar -xf ./environment-resources/icons/01-Flat-Remix-Blue-20250709.tar.xz -C ~/.icons/
  gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'

  install_yay

  log_info "Installing AUR packages..."
  yay -S --removemake --noconfirm --needed \
    neofetch \
    ookla-speedtest-bin \
    spotify \
    vscodium-bin

  log_info "Copying VSCodium settings to ~/.config/VSCodium/User..."
  mkdir -p ~/.config/VSCodium/User/
  cp -f environment-resources/vscodium/settings.json ~/.config/VSCodium/User/

  log_info "Installing oh-my-zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  sed -i 's/^ZSH_THEME="robbyrussell"/ZSH_THEME="bira"/' ~/.zshrc

  log_info "Copying nano configuration..."
  cp environment-resources/nano-config/.nanorc ~/

  log_succes "Hyprland environment installation completed!"
  hypr_copy_config
  ask_reboot
}

hypr_copy_config () {
  log_info "Select Hyprland config to copy:"
  echo "  1) Config 1 for laptop"
  echo "  2) Config 2 fot desktop"
  echo "  0) Exit the script."

  log_qa "Enter choice [1/2]:"
  read -r choice

  case "$choice" in
    1)
      HYPR_CONFIG_OPTION="hyprland-config-01"

      log_info "Configure Adwaita-dark theme"
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
      ;;
    2)
      HYPR_CONFIG_OPTION="hyprland-config-02"

      log_info "Configure Adwaita-dark theme"
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
      ;;
    0)
      log_info "Exiting the script."
      return
      ;;
    *)
      log_error "Invalid choice. Aborting."
      log_error "Use: --help options"
      return
      ;;
  esac
  log_qa "Do you want to copy hyprland config to .config? [Y/n]:"
  read -r confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    COPY_CONFIG_FOLDERS=("hypr" "kitty" "waybar" "wofi" "mako" "gtk-3.0" "xfce4" "Thunar" "mimeapps.list" "imv")
    COPY_LOCAL_SHARE_FOLDERS=("Thunar")

    mkdir -p "$HOME/.config"
    for cfg in "${COPY_CONFIG_FOLDERS[@]}"; do
        SRC="./environment-resources/$HYPR_CONFIG_OPTION/config/$cfg"

        if [ -d "$SRC" ]; then
          echo "--> Copying directory $cfg to ~/.config"
          cp -rf "$SRC" "$HOME/.config"
        elif [ -f "$SRC" ]; then
          echo "--> Copying file $cfg ~/.config"
          cp -f "$SRC" "$HOME/.config/"
        else
          echo "!! $cfg not found, skipping"
        fi
    done

    mkdir -p "$HOME/.local/share"
    for cfg in "${COPY_LOCAL_SHARE_FOLDERS[@]}"; do
      SRC="./environment-resources/$HYPR_CONFIG_OPTION/local/$cfg"

      if [ -d "$SRC" ]; then
        echo "--> Copying directory $cfg to ~/.local/share"
        cp -rf "$SRC" "$HOME/.local/share"
      elif [ -f "$SRC" ]; then
        echo "--> Copying file $cfg to ~/.local/share"
        cp -f "$SRC" "$HOME/.local/share/"
      else
        echo "!! $cfg not found, skipping"
      fi
    done

    WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"
    ZIP_FILE="/tmp/wallpapers.zip"
    DROPBOX_URL="https://www.dropbox.com/scl/fo/0m9gabhe0xs9hb5akkkg6/APAqNzDTPFV-xaLhs1ivcaw?rlkey=i56zh4sma32ydrianlmdy3dzj&st=wha573co&dl=1"

    if [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR")" ]; then
      printf "${BLUE}[i] Downloading wallpapers... ${RESET}"
      wget -q -O "$ZIP_FILE" "$DROPBOX_URL"
      printf "${GREEN}Done${RESET}\n"

      printf "${BLUE}[i] Extracting wallpapers... ${RESET}"
      unzip -o "$ZIP_FILE" -d "$WALLPAPER_DIR" &>/dev/null || true
      printf "${GREEN}Done${RESET}\n"

      printf "${BLUE}[i] Removing /tmp/wallpapers.zip... ${RESET}"
      rm "$ZIP_FILE"
      printf "${GREEN}Done${RESET}\n"
    else
      log_info "Wallpapers already exist, skipping download."
    fi

    log_succes "Hyprland configuration $choice copy completed"
  fi
}

install_xorg() {
  local mode=$1

  log_info "Installing X server packages for '$mode'..."

case "$mode" in
  x11)
    sudo pacman -S --noconfirm --needed xorg xorg-xinit
    ;;
  wayland)
    sudo pacman -S --noconfirm --needed \
      wayland \
      wayland-protocols \
      xorg-xwayland \
      xorg-xhost
    ;;
  *)
    log_error "Unknown mode: $mode. Use 'x11' or 'wayland'."
    return 1
    ;;
esac

  log_succes "Xorg installation for '$mode' completed!"
}

install_yay() {
  if ! command -v yay &>/dev/null; then
    log_info "Installing yay AUR helper..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
  else
    log_succes "yay already installed."
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

install_game_setup() {
  log_info "Installing game setup..."

  log_info "Enabling miltilib repository..."
  sudo sed -i '/^\[multilib\]/s/^#//' /etc/pacman.conf
  sudo sed -i '/Include = \/etc\/pacman.d\/mirrorlist/s/^#//' /etc/pacman.conf
  sudo pacman -Sy

  log_info "Installing Radeon packages..."
  sudo pacman -S --noconfirm --needed \
    mesa \
    lib32-mesa \
    vulkan-radeon \
    lib32-vulkan-radeon \
    \
    vulkan-tools \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    vulkan-mesa-layers \
    radeontop \
    gamescope \
    gamemode \
    mangohud \
    \
    corectrl \
    \
    steam

  install_yay

  yay -S --removemake --noconfirm --needed \
    dxvk-bin \
    protontricks \
    \
    heroic-games-launcher-bin
}

ask_reboot() {
  log_qa "Do you want to restart system? [Y/n]:"
  read -r confirm
  [[ "$confirm" =~ ^(n|no)$ ]] || reboot
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
  --archinstall)
    install_from_archinstall

    log_info "Copying arch-setup repository to chroot to continue ssytem installaton.."
    cp -r ../arch-setup /mnt/root

    log_info "Running arch-setup - chroot postinstall..."
    arch-chroot /mnt /root/arch-setup/arch-setup.sh --chroot-postinstall
    ;;
  --install)
    log_qa "Are you sure you want to proceed? This will result in ${RED}DATA LOSS${YELLOW} on the media. [y/N]:"
    read -r confirm
    confirm=${confirm,,}

    if [[ "$confirm" != "y" ]]; then
      echo "Operation cancelled."
      exit 1
    else
      partition_disk "$2"
      install_pacstrap
      generate_fstab

      log_qa "Would you like to copy this script to /mnt/root to complete the installation? [Y/n]:"
      read -r confirm
      confirm=${confirm,,}
      if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
        echo "${BLUE}[i] Copying arch-setup to /mnt/root...${RESET}"
        cp -r ../arch-setup /mnt/root/
        arch-chroot /mnt /root/arch-setup/arch-setup.sh --chroot-postinstall

        log_info "Select bootloader to install:"
        echo "  1) systemd-boot"
        echo "  2) GRUB (EFI)"
        echo "  0) Exit"
        log_qa "Enter choice [1/2]:"
        read -r choice

        case "$choice" in
          1)
            arch-chroot /mnt /root/arch-setup/arch-setup.sh --install-systemd-boot "$ROOTFS_PARTITION"
            ask_reboot
            ;;
          2)
            arch-chroot /mnt /root/arch-setup/arch-setup.sh --install-grub
            ask_reboot
            ;;
          0)
            log_info "Exiting the script."
            return
            ;;
          *)
            ;;
        esac
      fi
    fi
    ;;
  --chroot-postinstall)
    chroot_postinstall
    ;;
  --install-systemd-boot)
    install_systemd_boot "$2"
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
  --install-base-packages)
    install_base_packages
    ;;
  --install-hamradio-setup)
    install_hamradio_packages
    ;;
  --install-game-setup)
    install_game_setup
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
    echo "    --archinstall                    - Install from archinstall script with custom config"
    echo "    --install /dev/sdX               - Installing the system without using the archinstall script"
    echo "    --chroot-postinstall             - Configure post-installation system settings"
    echo "    --install-base-packages          - Install base packages and enable services"
    echo ""
    echo ">>> Bootloaders:"
    echo "    --install-systemd-boot /dev/sdaX - Install systemd-boot EFI bootloader"
    echo "    --install-grub                   - Install GRUB bootloader (EFI)"
    echo "    --remove-grub                    - Remove GRUB bootloader (EFI)"
    echo ""
    echo ">>> Packages"
    echo "    --install-yay                    - Install yay AUR helper"
    echo "    --install-vbox                   - Install VirtualBox"
    echo "    --install-fingerprint            - Install fingerprint login option (Untested yet, not work with pam configuration)"
    echo "    --install-hamradio-setup         - Install Ham Radio setup"
    echo "    --install-game-setup             - Install game setup (Radeon only)"
    echo ""
    echo ">>> Desktop environment installation options:"
    echo "    --install-xfce                   - Install XFCE desktop environment"
    echo "    --install-plasma                 - Install KDE Plasma desktop environment"
    echo "    --install-hyprland               - Install Hyprland Wayland compositor"
    echo "    --copy-hypr-config               - Copy custom Hyprland configuration files"
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
