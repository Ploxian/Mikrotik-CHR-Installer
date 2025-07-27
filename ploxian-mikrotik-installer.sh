#!/bin/bash -e

# ==============================================================================
# Title   : MikroTik CHR Installer Script
# Author  : Ploxian
# GitHub  : https://github.com/Ploxian
# Version : 1.2
# ==============================================================================

CHR_VERSION="7.19.3"
CHR_URL="https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip"
CHR_ZIP="/tmp/chr.img.zip"
CHR_IMG="/tmp/chr.img"

# -------------------------
# Colored message helpers
# -------------------------
info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
warn()    { echo -e "\e[33m[WARN]\e[0m $1"; }
error()   { echo -e "\e[31m[ERROR]\e[0m $1" >&2; }

# -------------------------
# Banner function
# -------------------------
print_banner() {
  clear
  echo -e "\e[36m"
  cat << "EOF"
 __  __ _ _       _        _____ _   _ _____ ____  
|  \/  (_) |     | |      |_   _| \ | | ____|  _ \ 
| |\/| |_| |_ ___| |__      | | |  \| |  _| | | | |
| |  | | | __/ __| '_ \     | | | |\  | |___| |_| |
|_|  |_|_|\__\___|_.__/     |_| |_| \_|_____|____/ 
      MikroTik CHR + IP Auto Config Installer
EOF
  echo -e "\e[0m"
}

# -------------------------
# Cleanup temp files
# -------------------------
cleanup() {
  rm -f "$CHR_ZIP" "$CHR_IMG" 2>/dev/null
  success "Temporary files cleaned up"
}

# -------------------------
# Check root permission
# -------------------------
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root."
    exit 1
  fi
}

# -------------------------
# Install unzip if missing
# -------------------------
check_dependencies() {
  if ! command -v unzip &>/dev/null; then
    info "Installing 'unzip'..."
    apt update -y && apt install -y unzip || {
      error "Failed to install unzip."
      exit 1
    }
  fi
}

# -------------------------
# Select target disk
# -------------------------
select_disk() {
  info "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "NAME"

  while true; do
    read -rp "Enter the disk to flash CHR (e.g. sda, vda): " DISK
    DISK=${DISK//\/dev\//}
    if [[ -b "/dev/$DISK" ]]; then
      warn "⚠️ This will erase ALL DATA on /dev/$DISK!"
      read -rp "Are you sure? Type 'yes' to continue: " CONFIRM
      [[ "$CONFIRM" == "yes" ]] && break
    else
      error "/dev/$DISK not found. Try again."
    fi
  done
}

# -------------------------
# Get interface, IP, gateway
# -------------------------
get_network_info() {
  INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
  INTERFACE_IP=$(ip -4 addr show "$INTERFACE" | grep inet | awk '{print $2}' | head -n 1)
  INTERFACE_GATEWAY=$(ip route | grep default | awk '{print $3}')

  info "Detected network interface: $INTERFACE"
  info "Interface IP: $INTERFACE_IP"
  info "Default gateway: $INTERFACE_GATEWAY"
}

# -------------------------
# Write autorun script into image
# -------------------------
inject_network_config() {
  mkdir -p /mnt/chr
  mount -o loop,offset=512 "$CHR_IMG" /mnt/chr || {
    error "Failed to mount image."
    cleanup
    exit 1
  }

  cat <<EOF > /mnt/chr/rw/autorun.scr
/ip address add address=${INTERFACE_IP} interface=[/interface ethernet find where name=ether1]
/ip route add gateway=${INTERFACE_GATEWAY}
EOF

  success "Network autorun script injected"
  umount /mnt/chr
}

# -------------------------
# Main logic
# -------------------------
main() {
  print_banner
  check_root
  check_dependencies
  select_disk
  get_network_info

  info "Downloading CHR image $CHR_VERSION..."
  wget -q --show-progress -O "$CHR_ZIP" "$CHR_URL" || {
    error "Failed to download CHR image."
    cleanup
    exit 1
  }

  info "Unzipping image..."
  unzip -o "$CHR_ZIP" -d /tmp/ || {
    error "Failed to unzip image."
    cleanup
    exit 1
  }

  mv "/tmp/chr-$CHR_VERSION.img" "$CHR_IMG"

  inject_network_config

  warn "About to write CHR image to /dev/$DISK. This is destructive!"
  read -rp "Final confirmation. Type 'yes' to write to disk: " FINAL_CONFIRM
  [[ "$FINAL_CONFIRM" != "yes" ]] && {
    info "Cancelled by user."
    cleanup
    exit 0
  }

  info "Writing image to /dev/$DISK..."
  dd if="$CHR_IMG" of="/dev/$DISK" bs=4M status=progress oflag=sync || {
    error "Failed to write image."
    cleanup
    exit 1
  }

  success "CHR successfully written to /dev/$DISK!"

  read -rp "Reboot now? (yes/no): " REBOOT_CONFIRM
  if [[ "$REBOOT_CONFIRM" == "yes" ]]; then
    info "Rebooting in 5 seconds..."
    sleep 5
    echo b > /proc/sysrq-trigger
  else
    info "Please reboot manually to start RouterOS CHR."
  fi

  cleanup
}

# Trap interrupt signals
trap 'error "Script interrupted."; cleanup; exit 1' SIGINT SIGTERM

# Run main
main
