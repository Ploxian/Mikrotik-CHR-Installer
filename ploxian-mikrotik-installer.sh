#!/bin/bash -e

# ==============================================================================
# Title   : MikroTik CHR Installer Script
# Author  : Ploxian
# GitHub  : https://github.com/Ploxian
# Version : 1.0
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
error()   { echo -e "\e[31m[ERROR]\e[0m $1"; }

# -------------------------
# ASCII art banner function
# -------------------------
print_banner() {
  clear
  echo -e "\e[36m"
  echo "  _____ _             _        __      __                 "
  echo " / ____| |           | |       \ \    / /                 "
  echo "| (___ | |_ __ _ _ __| |_ ___   \ \  / /__  _ __ ___  ___ "
  echo " \___ \| __/ _\` | '__| __/ __|   \ \/ / _ \| '__/ _ \/ __|"
  echo " ____) | || (_| | |  | |_\__ \    \  / (_) | | |  __/\__ \\"
  echo "|_____/ \__\__,_|_|   \__|___/     \/ \___/|_|  \___||___/"
  echo
  echo "               by Ploxian"
  echo -e "\e[0m"
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
    apt install -y "${packages[@]}"
  elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_ID" == "almalinux" || "$OS_ID" == "rocky" ]]; then
    # Use dnf if available, else yum
    if command -v dnf &>/dev/null; then
      info "Installing packages with dnf: ${packages[*]}"
      dnf install -y "${packages[@]}"
    else
      info "Installing packages with yum: ${packages[*]}"
      yum install -y "${packages[@]}"
    fi
  else
    error "Unsupported OS: $OS_NAME. Please install required packages manually: ${packages[*]}"
    exit 1
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
    read -p "Do you want to install missing packages now? (yes/no): " INSTALL_CONFIRM
    if [[ "$INSTALL_CONFIRM" == "yes" ]]; then
      install_packages "${MISSING[@]}"
    else
      error "Cannot continue without required packages. Exiting."
      exit 1
    fi
  fi
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

  info "Downloading MikroTik CHR $CHR_VERSION image..."
  wget -q --show-progress "$CHR_URL" -O "$CHR_ZIP"

  info "Unzipping image..."
  gunzip -c "$CHR_ZIP" > "$CHR_IMG"

  info "Detecting primary disk..."
  DISK=$(lsblk -ndo NAME,TYPE | grep 'disk' | awk '{print $1}' | head -n 1)

  if [ -z "$DISK" ]; then
    error "No disk found. Exiting."
    exit 1
  fi

  warn "Detected disk: /dev/$DISK"
  lsblk "/dev/$DISK"

  read -p "Are you sure you want to erase /dev/$DISK and install MikroTik CHR? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    info "Aborted by user."
    exit 0
  fi

  ETH=$(ip route show default | awk '/default/ {print $5}')
  ADDRESS=$(ip -o -f inet addr show $ETH | awk '{print $4}')
  GATEWAY=$(ip route | grep default | awk '{print $3}')

  info "Network interface: $ETH"
  info "IP address: $ADDRESS"
  info "Default gateway: $GATEWAY"

  info "Writing CHR image to /dev/$DISK (this will erase all data)..."
  dd if="$CHR_IMG" of="/dev/$DISK" bs=4M status=progress oflag=sync && \
  success "CHR image successfully written to /dev/$DISK." && \
  info "Rebooting system..." && \
  echo 1 > /proc/sys/kernel/sysrq && \
  echo b > /proc/sysrq-trigger && \
}

# Run main function
main
