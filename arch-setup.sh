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

text_blink="\e[5m"
color_green=$'\e[32m'
color_yellow=$'\e[33m'
color_red=$'\e[31m'
color_blue=$'\e[94m'
color_blue_light=$'\e[36m'
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

required_archiso() {
  if ! [[ -d /run/archiso ]]; then
    log_error "This option can only be run in the Archiso environment"
    exit 1
  fi
}

required_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script option must be run as root."
    exit 1
  fi
}

require_non_root() {
  if [[ $EUID -eq 0 ]]; then
    log_error "This script must NOT be run as root."
    exit 1
  fi
}

install_from_archinstall() (
  local user_config="environment-resources/archinstall-config/user_configuration.json"
  local user_creds="environment-resources/archinstall-config/user_credentials.json"

  archinstall --config $user_config --creds $user_creds
)

partition_disk() {
  required_root

  disk="$1"

  log_info "Creating a new GPT table on... $disk"

  parted -s "$disk" mklabel gpt

  log_info "Creating the EFI partition (512MiB)..."
  parted -s "$disk" --align optimal mkpart ESP fat32 1MiB 513MiB
  parted -s "$disk" set 1 esp on

  log_info "Creating the root partition (rest of the disk, Btrfs)..."
  parted -s "$disk" --align optimal mkpart primary btrfs 513MiB 100%

  log_info "Setting correct partition type GUIDs..."
  sgdisk --typecode=1:ef00 "$disk"                                 # EFI System Partition tyoe
  sgdisk --typecode=2:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 "$disk" # Linux root (x86_64) type

  if [[ "$disk" == *"nvme"* || "$disk" == *"mmcblk"* ]]; then
      partition_1="${disk}p1"
      partition_2="${disk}p2"
  else
      partition_1="${disk}1"
      partition_2="${disk}2"
  fi

  rootfs_partition=$partition_2

  log_info "Formatting EFI... ($partition_1)"
  mkfs.fat -F32 "$partition_1"

  log_info "Formatting Btrfs... ($partition_2)"
  mkfs.btrfs -f "$partition_2"

  log_info "Creating Btrfs subvolumes..."
  mount "$partition_2" /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@root
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@var_cache
  btrfs subvolume create /mnt/@var_log
  btrfs subvolume create /mnt/@.snapshots
  umount /mnt

  log_info "Mounting subvolumes..."
  mount -o subvol=@ "$partition_2" /mnt
  mkdir -p /mnt/{root,home,.snapshots,boot}
  mkdir -p /mnt/var/{cache,log}
  mount -o subvol=@root       "$partition_2" /mnt/root
  mount -o subvol=@home       "$partition_2" /mnt/home
  mount -o subvol=@var_cache  "$partition_2" /mnt/var/cache
  mount -o subvol=@var_log    "$partition_2" /mnt/var/log
  mount -o subvol=@.snapshots "$partition_2" /mnt/.snapshots
  mount "$partition_1" /mnt/boot

  log_succes "Done! The $disk disk has been prepared and mounted to /mnt"
  log_info "Now run: genfstab -U /mnt >> /mnt/etc/fstab"
}

install_pacstrap() {
  pacstrap -K /mnt base linux linux-firmware
}

generate_fstab() {
  genfstab -U /mnt >> /mnt/etc/fstab
}

install_systemd_boot() {
  local disk="$1"

  log_info "Installing systemd-boot..."
  bootctl install

  log_info "Creating loader.conf..."
  cat <<EOF > /boot/loader/loader.conf
timeout 1
EOF

  log_info "Creating boot entries..."
  root_partuuid=$(blkid -s PARTUUID -o value "$disk")
  date=$(date +%Y-%m-%d_%H-%M-%S)
  entry_dir="/boot/loader/entries"

  mkdir -p "$entry_dir"

  cat <<EOF > "$entry_dir/${date}_linux.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$root_partuuid rootflags=subvol=@ rw rootfstype=btrfs
EOF

  cat <<EOF > "$entry_dir/${date}_linux-fallback.conf"
title   Arch Linux (linux-fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options root=PARTUUID=$root_partuuid rootflags=subvol=@ rw rootfstype=btrfs
EOF

  log_succes "systemd-boot has been installed and boot entries created"
}

install_grub() {
  required_root

  if ! mount | grep -q '/boot type vfat'; then
    log_error "/boot is not mounted or is not a vfat EFI partition!"
    exit 1
  fi

  if [[ -d /boot/EFI/GRUB ]]; then
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
  required_root

  log_qa "Do you realy want remove GRUB bootloader? [N/y]:"
  read -r confirm
  confirm=${confirm,,}
  if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
    if [[ -d /boot/EFI ]]; then
      log_info "Deleting /boot/EFI..."
      rm -rf /boot/EFI
    fi

    if [[ -d /boot/grub ]]; then
      log_info "Deleting /boot/grub..."
      rm -rf /boot/grub
    fi
  fi
}

chroot_postinstall() {
  required_root

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
  read -r hostname
  if [[ -z "$hostname" ]]; then
    log_error "No hostname entered, using default: archlinux"
    hostname="archlinux"
  fi
  echo "$hostname" > /etc/hostname
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

  mirrors=(
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

  for mirror in "${mirrors[@]}"; do
    echo "Server = $mirror" >> /mnt/etc/pacman.d/mirrorlist
  done

  log_succes "Mirrorlist configured with all Germany + Poland mirrors"
}

install_base_packages() {
  required_root

  log_info "Installing essential packages..."
  pacman -S --noconfirm --needed \
    sudo \
    usbutils \
    nano \
    zsh \
    git \
    cmake \
    which \
    wget \
    htop \
    base-devel \
    \
    acpi \
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
  require_non_root
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
  required_root

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

      if [[ ! -f /etc/modprobe.d/disable-kvm.conf ]]; then
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

  if [[ -z "$latest_version" ]]; then
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
  if [[ -x /sbin/vboxconfig ]]; then
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
  require_non_root
  install_audio
  install_display_stack "x11"

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
  require_non_root
  install_audio
  install_display_stack "wayland"

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

install_wayland_env() {
  require_non_root
  local window_manager="$1"

  if [[ "$window_manager" != "hyprland" && "$window_manager" != "sway" ]]; then
    log_error "Usage: install_wayland_env [hyprland|sway]"
    return 1
  fi

  install_audio
  install_display_stack "wayland"

  log_info "Installing base Wayland environment..."

  base_packages=(
    xdg-desktop-portal
    xdg-utils
    wl-clipboard

    waybar
    mako
    brightnessctl

    grim
    slurp

    wofi
    kitty
    mousepad

    thunar
    thunar-archive-plugin
    thunar-media-tags-plugin
    gnome-disk-utility

    gvfs gvfs-smb gvfs-nfs gvfs-mtp gvfs-gphoto2
    android-udev

    zip unzip unrar p7zip xarchiver rsync

    network-manager-applet
    bluez bluez-utils blueman

    pavucontrol

    otf-font-awesome
    ttf-nerd-fonts-symbols
    gnome-themes-extra

    polkit-gnome
    gnome-keyring
    seahorse
    gparted

    ly

    firefox thunderbird filezilla

    mpv
    libreoffice-fresh
    imagemagick

    flatpak
    jq
  )

case "$window_manager" in
  hyprland)
    wm_packages=(
      hyprland
      xdg-desktop-portal-hyprland
      hypridle
      swaybg
      swaylock
      ristretto
    )
    ;;
  sway)
    wm_packages=(
      sway
      swayidle
      swaybg
      swaylock
      xdg-desktop-portal-wlr
      imv
    )
    ;;
  *)
    log_error "Unsupported window manager: $window_manager"
    log_info "Available options: hyprland, sway"
    return 1
    ;;
esac

  log_info "Installing $window_manager..."
  sudo pacman -S --noconfirm --needed \
    "${base_packages[@]}" \
    "${wm_packages[@]}"

  log_info "Installing flatpak packages..."
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y \
    org.keepassxc.KeePassXC \
    com.spotify.Client

  log_info "Disabling & masking getty service on tty1..."
  sudo systemctl disable getty@tty1.service
  sudo systemctl mask getty@tty1.service

  log_info "Enabling ly login manager..."
  sudo systemctl enable ly@tty1.service

  log_info "Enabling bluetooth..."
  sudo systemctl enable bluetooth

  log_info "Enabling audio..."
  systemctl --user enable --now pipewire.service
  systemctl --user enable --now wireplumber.service

  log_info "Installing icons..."
  mkdir -p ~/.icons
  tar -xf ./environment-resources/icons/Flat-Remix-Blue-20251119.tar.xz -C ~/.icons/
  tar -xf ./environment-resources/icons/Flat-Remix-Orange-20251119.tar.xz -C ~/.icons/
  tar -xf ./environment-resources/icons/Flat-Remix-Red-20251119.tar.xz -C ~/.icons/
  tar -xf ./environment-resources/icons/Flat-Remix-Yellow-20251119.tar.xz -C ~/.icons/

  install_yay

  log_info "Installing AUR packages..."
  yay -S --removemake --noconfirm --needed \
    neofetch \
    vscodium-bin

  install_net_diag_setup

  log_info "Copying VSCodium settings..."
  mkdir -p ~/.config/VSCodium/User/
  cp -f environment-resources/vscodium/settings.json ~/.config/VSCodium/User/

  log_info "Installing oh-my-zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  sed -i 's/^ZSH_THEME="robbyrussell"/ZSH_THEME="bira"/' ~/.zshrc

  log_info "Copying nano configuration..."
  cp environment-resources/nano-config/.nanorc ~/

  log_succes "$window_manager environment installation completed!"

  copy_wm_config "$window_manager"
  ask_reboot
}

copy_wm_config() {
  require_non_root
  local window_manager="$1"

  log_info "Select $window_manager config to copy:"
    cat << EOF
 1) Config 1 for Lenovo ThinkPad T470
 2) Config 2 for PC
 0) Exit the script
EOF

  log_qa "Enter choice:"
  read -r choice

  case "$window_manager" in
    hyprland) wm_config_dir="hypr" ;;
    sway) wm_config_dir="sway" ;;
    *)
      log_error "Unsupported window_manager: $window_manager"
      return 1
      ;;
  esac

  case "$choice" in
    1)
      wm_config_option="$window_manager-config-01"
      gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'
      ;;
    2)
      wm_config_option="$window_manager-config-02"
      gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Orange-Dark'
      ;;
    0) log_info "Exiting the script."; return ;;
    *) log_error "Invalid choice."; return ;;
  esac

  common_config_folder="common-config"

  log_qa "Do you want to copy $window_manager config to .config? [Y/n]:"
  read -r confirm
  confirm=${confirm,,}
  [[ ! "$confirm" =~ ^(y|yes|)$ ]] && return

  copy_wm_config_folders=("$wm_config_dir" "waybar")
  copy_common_config_folders=("kitty" "wofi" "mako" "gtk-3.0" "xfce4" "Thunar" "mimeapps.list" "imv")
  copy_local_share_folders=("Thunar")

  copy_config_items "./environment-resources/$wm_config_option/config"   "$HOME/.config/"       "${copy_wm_config_folders[@]}"
  copy_config_items "./environment-resources/$common_config_folder/config" "$HOME/.config/"      "${copy_common_config_folders[@]}"
  copy_config_items "./environment-resources/$common_config_folder/local"  "$HOME/.local/share/" "${copy_local_share_folders[@]}"

  wallpapers_dir="$HOME/.config/wallpapers"
  zip_file="/tmp/wallpapers.zip"
  dropbox_url="https://www.dropbox.com/scl/fo/0m9gabhe0xs9hb5akkkg6/APAqNzDTPFV-xaLhs1ivcaw?rlkey=i56zh4sma32ydrianlmdy3dzj&st=wha573co&dl=1"

  if [[ ! -d $wallpapers_dir || -z $(compgen -A file "$wallpapers_dir") ]]; then
    log_info "Downloading wallpapers..."
    wget -q -O "$zip_file" "$dropbox_url"
    log_info "Extracting wallpapers..."
    unzip -o "$zip_file" -d "$wallpapers_dir" &>/dev/null || true
    rm "$zip_file"
  else
    log_info "Wallpapers already exist, skipping download."
  fi

  log_succes "Sway configuration $choice copy completed"
}

install_display_stack() {
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
  require_non_root
  if ! command -v yay &>/dev/null; then
    log_info "Installing yay AUR helper..."
    sudo pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
  else
    log_succes "yay already installed."
  fi
}

install_net_diag_setup() {
  require_non_root
  log_info "Installing network diagnostic packages"

  install_yay

  sudo pacman -S --noconfirm --needed \
    nmap \
    iperf3 \
    mtr \
    wireshark-qt \
    screen

  yay -S --removemake --noconfirm --needed \
    winbox \
    ookla-speedtest-bin \
    netcalc \
    netchecker
}

install_game_setup() {
  require_non_root
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

copy_config_items() {
  local src_base="$1"
  local dest_base="$2"
  shift 2
  local items=("$@")

  dest_base="${dest_base/#\~/$HOME}"
  dest_base="${dest_base//\/\//\/}"
  dest_base="${dest_base%/}"

  local dest_print="${dest_base/#$HOME/~}"

  for item in "${items[@]}"; do
    local src="$src_base/$item"

    if [[ -d "$src" ]]; then
      printf -- "--> 📁 %-18s → %s/\n" "$item" "$dest_print/${color_yellow}$item${color_reset}"
      cp -rf "$src" "$dest_base/"
    elif [[ -f "$src" ]]; then
      printf -- "--> 📄 %-18s → %s/\n" "$item" "$dest_print/${color_yellow}$item${color_reset}"
      cp -f "$src" "$dest_base/"
    else
      printf -- "--> ⚠️ %-18s (not found)\n" "$item"
    fi
  done
}

print_summary() {
  local disk=$1
  local part_1
  local part_2

  if [[ "$disk" == *"nvme"* || "$disk" == *"mmcblk"* ]]; then
      part_1="${disk}p1"
      part_2="${disk}p2"
  else
      part_1="${disk}1"
      part_2="${disk}2"
  fi

  print_logo bl
  cat << EOF
   ========================================
      Arch Setup - Installation Summary
   ========================================

   Disk:        $disk

   Partitions (planned):
     - EFI:     ${part_1}  (512MiB, FAT32)
     - Root:    ${part_2}  (rest, Btrfs)

   Filesystem:  Btrfs

   Subvolumes:
     - @             -> /
     - @root         -> /root
     - @home         -> /home
     - @var_cache    -> /var/cache
     - @var_log      -> /var/log
     - @.snapshots   -> /.snapshots

   ========================================
   ${text_blink}${color_red}⚠️  ALL DATA ON $disk WILL BE LOST!${color_reset}
   ========================================

EOF
}

installation_countdown() {
    for i in 5 4 3 2 1; do
        for c in / - \\ \|; do
            printf "\r${color_blue}[%s] Start installation in %d second... ${color_reset}" "$c" "$i"
            sleep 0.25
        done
    done
    printf "\r\033[K${color_blue}[${char_info}] Installation in progress...${color_reset}\n"
}

print_logo() {
    local color_name="${1:-white}"
    local color

case "${color_name,,}" in
    g|green) color=$color_green ;;
    y|yellow) color=$color_yellow ;;
    r|red) color=$color_red ;;
    b|blue) color=$color_blue ;;
    bl|blue-light) color=$color_blue_light ;;
    w|white|"") color=$WHITE ;;
    *) color=$WHITE ;;
esac

  printf "%b" "${color}"
  cat << 'EOF'

       /\                                                                            .--.
      /  \           ___    ____  ________  __     _____ ______________  ______     |o_o |
     /\   \         /   |  / __ \/ ____/ / / /    / ___// ____/_  __/ / / / __ \    ||_/ |
    /      \       / /| | / /_/ / /   / /_/ /_____\__ \/ __/   / / / / / / /_/ /   //   \ \
   /   ,,   \     / ___ |/ _, _/ /___/ __  /_____/__/ / /___  / / / /_/ / ____/   (|     | )
  /   |  |  -\   /_/  |_/_/ |_|\____/_/ /_/     /____/_____/ /_/  \____/_/        /'\_  _/`\
 /_-''    ''-_\                                                                   \__)=(___/

EOF
  printf "%b" "${color_reset}"
}

print_help() {
  print_logo bl

  cat << 'EOF'
USAGE:
    arch-setup [option]

COMMANDS:

SYSTEM:
    --archinstall                       Install from archinstall script with custom config
    --install /dev/sdX                  Installing the system without using the archinstall script
    --chroot-postinstall                Configure post-installation system settings
    --install-base-packages             Install base packages and enable services

BOOTLOADERS:
    --install-systemd-boot /dev/sdaX    Install systemd-boot EFI bootloader
    --install-grub                      Install GRUB bootloader (EFI)
    --remove-grub                       Remove GRUB bootloader (EFI)

PACKAGES:
    --install-yay                       Install yay AUR helper
    --install-vbox                      Install VirtualBox
    --install-hamradio-setup            Install Ham Radio setup
    --install-game-setup                Install game setup (Radeon only)

DESKTOP:
    --install-xfce                      Install XFCE desktop environment
    --install-plasma                    Install KDE Plasma desktop environment
    --install-hyprland                  Install Hyprland Wayland compositor
    --copy-hypr-config                  Copy custom Hyprland configuration files
    --install-sway                      Install Sway Wayland compositor
    --copy-sway-config                  Copy custom Sway configuration files

OPTIONS:
    -f, --force                         Force reinstall (e.g., overwrite existing GRUB installation)
EOF
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
    required_archiso

    clear
    print_logo bl
    install_from_archinstall

    log_info "Copying arch-setup repository to chroot to continue ssytem installaton.."
    cp -r ../arch-setup /mnt/root

    log_info "Running arch-setup - chroot postinstall..."
    arch-chroot /mnt /root/arch-setup/arch-setup.sh --chroot-postinstall
    ;;
  --install)
    required_archiso
    clear

    print_summary "$2"

    log_qa "Are you sure you want to proceed? This will result in ${color_red}DATA LOSS${color_yellow} on the media. [y/N]:"
    read -r confirm
    confirm=${confirm,,}

    if [[ "$confirm" != "y" ]]; then
      echo "Operation cancelled."
      exit 1
    else
      installation_countdown

      partition_disk "$2"
      install_pacstrap
      generate_fstab

      log_qa "Would you like to copy this script to /mnt/root to complete the installation? [Y/n]:"
      read -r confirm
      confirm=${confirm,,}
      if [[ "$confirm" =~ ^(y|yes|)$ ]]; then
        echo "${color_blue}[i] Copying arch-setup to /mnt/root...${color_reset}"
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
            arch-chroot /mnt /root/arch-setup/arch-setup.sh --install-systemd-boot "$rootfs_partition"
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
    install_wayland_env hyprland
    ;;
  --copy-hypr-config)
    copy_wm_config hyprland
    ;;
  --install-sway)
    install_wayland_env sway
    ;;
  --copy-sway-config)
    copy_wm_config sway
    ;;
  --install-yay)
    install_yay
    ;;
  --install-vbox)
    install_virtualbox
    ;;
  --help)
    print_help
    ;;
  *)
    echo "Use: --help options"
    exit 1
    ;;
esac
