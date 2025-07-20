
# MikroTik CHR Installer Script

**Author:** Ploxian  
**GitHub:** [https://github.com/Ploxian](https://github.com/Ploxian)  
**Version:** 1.0

---

## Overview

This script automates the installation of MikroTik RouterOS Cloud Hosted Router (CHR) version **7.19.3** onto a Linux system’s primary disk. It safely downloads the official CHR image, flashes it to the detected disk, and optionally reboots into MikroTik RouterOS.

---

## Why

Cause my VPS provider didn't had any option to use custom ISO(s) or any other means to install Mikrotik and I was doing Network Course at that time and it was crucial for me to have a testing setup.

---

## Features

- Auto-detects Linux OS (Debian/Ubuntu or RHEL/CentOS/AlmaLinux)
- Installs missing required dependencies (`wget`, `gunzip`, `dd`, `lsblk`, `ip`, `awk`, `grep`)
- Detects primary disk and confirms before overwriting
- Displays network interface info (interface, IP, gateway)
- Provides a colorful ASCII art banner on script start
- Requires root privileges to run
- Safe, interactive prompts before any destructive actions

---

## Requirements

- A Linux system with internet connectivity
- Root or sudo privileges
- Supported distros: Debian, Ubuntu, CentOS, RHEL, AlmaLinux, Rocky Linux (others may require manual package install)

---

## Usage

1. **Download the script**

   ```bash
   wget https://raw.githubusercontent.com/Ploxian/Mikrotik-CHR-Installer/main/ploxian-mikrotik-installer.sh
   ```

2. **Make it executable**

   ```bash
   chmod +x ploxian-mikrotik-installer.sh
   ```

3. **Run the script as root**

   ```bash
   sudo ./ploxian-mikrotik-installer.sh
   ```

4. Follow the interactive prompts carefully:
   - Confirm installation disk (all data on it will be erased)
   - Confirm reboot option after installation

---

## Safety Notes

- The script **will overwrite your selected disk** completely. Make sure you do **not** run it on a disk containing important data.
- Always have backups before running disk-level operations.
- The script will **not reboot without your explicit confirmation**.
- If required dependencies are missing, the script can install them automatically on supported distros.

---

## License

This script is provided as-is, without warranty. Use at your own risk.

---

## Contact

For questions or suggestions, please open an issue or contact [Ploxian](https://github.com/Ploxian).

---

**Happy routing!**
