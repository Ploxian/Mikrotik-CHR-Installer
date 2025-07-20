#!/bin/bash -e

# ==============================================================================
# Title   : MikroTik CHR Installer Script
# Author  : Ploxian
# GitHub  : https://github.com/Ploxian
# Version : 2.0
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
# ASCII art banner function
# -------------------------
print_banner() {
  clear
  echo -e "\e[36m"
  cat << "BANNER"
  _____ _             _        __      __                 
 / ____| |           | |       \ \    / /                 
| (___ | |_ __ _ _ __| |_ ___   \ \  / /__  _ __ ___  ___ 
 \___ \| __/ _` | '__| __/ __|   \ \/ / _ \| '__/ _ \/ __|
 ____) | || (_| | |  | |_\__ \    \  / (_) | | |  __/\__ \
|_____/ \__\__,_|_|   \__|___/     \/ \___/|_|  \___||___/
               
               by Ploxian (v2.0)
BANNER
  echo -e "\e[0m"
}

# -------------------------
# Cleanup function
# -------------------------
cleanup() {
  rm -f "$CHR_ZIP" "$CHR_IMG" 2>/dev/null
  success "Temporary files cleaned up"
}

# -------------------------
# Root user check
# -------------------------
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use sudo."
    exit 1
  fi
}

# -------------------------
# OS detection function
# -------------------------
detect_os() {
  if [ -e /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_NAME=$NAME
  else
    OS_ID=$(uname -s)
    OS_NAME=$OS_ID
  fi
}

# -------------------------
# Package installer by OS
# -------------------------
install_packages() {
  local packages=("$@")
  if [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
    info "Updating apt package list..."
    apt update -y
    info "Installing packages: ${packages[*]}"
    apt install -y "${packages[@]}" || {
      error "Failed to install packages"
      return 1
    }
  elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_ID" == "almalinux" || "$OS_ID" == "rocky" ]]; then
    if command -v dnf &>/dev/null; then
      info "Installing packages with dnf: ${packages[*]}"
      dnf install -y "${packackages[@]}" || return 1
    else
      info "Installing packages with yum: ${packages[*]}"
      yum install -y "${packages[@]}" || return 1
    fi
  else
    error "Unsupported OS: $OS_NAME. Please install required packages manually: ${packages[*]}"
    return 1
  fi
}

# -------------------------
# Check for required commands
# -------------------------
check_dependencies() {
  REQUIRED_CMDS=(wget gunzip dd lsblk ip awk grep)
  MISSING=()
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      MISSING+=("$cmd")
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing required packages: ${MISSING[*]}"
    read -rp "Do you want to install missing packages now? (yes/no): " INSTALL_CONFIRM
    if [[ "$INSTALL_CONFIRM" == "yes" ]]; then
      install_packages "${MISSING[@]}" || {
        error "Failed to install required packages. Exiting."
        exit 1
      }
    else
      error "Cannot continue without required packages. Exiting."
      exit 1
    fi
  fi
}

# -------------------------
# Disk selection function
# -------------------------
select_disk() {
  info "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "NAME"
  
  while true; do
    read -rp "Enter the disk device name (e.g. sda, vda): " DISK
    DISK=${DISK//\/dev\//}
    
    # Validate disk exists
    if [[ -e "/dev/$DISK" ]]; then
      # Check if disk is system disk
      if grep -q "/dev/$DISK" /proc/mounts; then
        warn "WARNING: $DISK contains mounted partitions!"
        read -rp "Are you absolutely sure you want to use this disk? (yes/no): " CONFIRM_DANGER
        [[ "$CONFIRM_DANGER" == "yes" ]] && break
      else
        break
      fi
    else
      error "Disk /dev/$DISK not found. Please try again."
    fi
  done
}

# -------------------------
# Network info function
# -------------------------
get_network_info() {
  DEFAULT_IF=$(ip route show default | awk '/default/ {print $5}')
  [[ -n "$DEFAULT_IF" ]] && {
    IP_INFO=$(ip -o -f inet addr show "$DEFAULT_IF")
    GATEWAY=$(ip route | awk '/default/ {print $3}')
    
    info "Network interface: $DEFAULT_IF"
    echo "$IP_INFO" | while read -r line; do
      info "IP address: $(echo "$line" | awk '{print $4}')"
    done
    info "Default gateway: $GATEWAY"
  } || warn "No default route found"
}

# -------------------------
# Main installer logic
# -------------------------
main() {
  print_banner
  check_root
  detect_os
  info "Detected OS: $OS_NAME ($OS_ID)"
  check_dependencies
  
  # Cleanup any existing files
  rm -f "$CHR_ZIP" "$CHR_IMG" 2>/dev/null
  
  # Download and extract image
  info "Downloading MikroTik CHR $CHR_VERSION image..."
  wget -q --show-progress "$CHR_URL" -O "$CHR_ZIP" || {
    error "Download failed"
    cleanup
    exit 1
  }
  
  info "Unzipping image..."
  gunzip -c "$CHR_ZIP" > "$CHR_IMG" || {
    error "Failed to extract image"
    cleanup
    exit 1
  }
  
  # Disk selection
  select_disk
  
  # Network info
  get_network_info
  
  # Final confirmation
  warn "\nTHIS WILL DESTROY ALL DATA ON /dev/$DISK!"
  read -rp "Are you sure you want to install to /dev/$DISK? (yes/no): " FINAL_CONFIRM
  [[ "$FINAL_CONFIRM" != "yes" ]] && {
    info "Installation canceled"
    cleanup
    exit 0
  }
  
  # Write image
  info "Writing CHR image to /dev/$DISK (this may take several minutes)..."
  dd if="$CHR_IMG" of="/dev/$DISK" bs=4M status=progress oflag=sync && {
    success "CHR image successfully written to /dev/$DISK"
  } || {
    error "Failed to write image to disk"
    cleanup
    exit 1
  }
  
  # Reboot prompt
  read -rp "Do you want to reboot now? (yes/no): " REBOOT_CONFIRM
  if [[ "$REBOOT_CONFIRM" == "yes" ]]; then
    info "System will reboot in 5 seconds..."
    sleep 5
    echo 1 > /proc/sys/kernel/sysrq
    echo b > /proc/sysrq-trigger
  else
    info "Please reboot manually to start CHR"
  fi
  
  cleanup
}

# Run main function and handle interrupts
trap 'error "Script interrupted by user"; cleanup; exit 1' SIGINT SIGTERM
main
