#!/usr/bin/env bash
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
                        SCRIPTHOME: ArchTitus
-------------------------------------------------------------------------

Final Setup and Configurations
"
source ${HOME}/ArchTitus/configs/setup.conf

if [[ -d "/sys/firmware/efi" ]]; then
  bootctl install --esp-path=/boot
  echo -ne "
default arch.conf
timeout 3
console-mode max
editor no
  " > /boot/loader/loader.conf
  echo -ne "
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options cryptdevice=UUID=$ENCRYPTED_PARTITION_UUID:ROOT:allow-discards root=/dev/mapper/ROOT rootflags=subvol=@ rd.luks.options=discard rw" > /boot/loader/entries/arch.conf
  if [[ "$microcode" ]]; then
    sed -i "1i|initramfs-linux|initrd /$microcode.img|" /boot/loader/entries/arch.conf
  fi
  if $SWAPFILE; then
    curl -LJO https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
    sed -i "s|rw|rw resume=/dev/mapper/ROOT resume_offset=$(./btrfs_map_physical /mnt/swapfile | head -n2 | tail -n1 | awk '{print $6}') / $(getconf PAGESIZE)|" /boot/loader/entries/arch.conf
  fi
fi

echo -ne "
-------------------------------------------------------------------------
               Enabling Login Display Manager
-------------------------------------------------------------------------
"
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  systemctl enable sddm.service
elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
  systemctl enable gdm.service
elif [[ ! "${DESKTOP_ENV}" == "server"  ]]; then
  systemctl enable lightdm.service
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
systemctl enable systemd-boot-update.service
echo "  Systemd boot autoupdate enabled"
systemctl enable cups.service
echo "  Cups enabled"
ntpd -qg
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl disable dhcpcd.service
echo "  DHCP disabled"
systemctl stop dhcpcd.service
echo "  DHCP stopped"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable bluetooth
echo "  Bluetooth enabled"
systemctl enable avahi-daemon.service
echo "  Avahi enabled"
systemctl enable fstrim.timer
echo "  Periodic Trim enabled"
systemctl enable systemd-resolved.service
echo "  Enable resolvconf"

if [[ "${FS}" == "luks" || "${FS}" == "btrfs" ]]; then
  echo -ne "
  -------------------------------------------------------------------------
                      Creating Snapper Config
  -------------------------------------------------------------------------
  "

  SNAPPER_CONF="$HOME/ArchTitus/configs/etc/snapper/configs/root"
  mkdir -p /etc/snapper/configs/
  cp -rfv ${SNAPPER_CONF} /etc/snapper/configs/

  SNAPPER_CONF_D="$HOME/ArchTitus/configs/etc/conf.d/snapper"
  mkdir -p /etc/conf.d/
  cp -rfv ${SNAPPER_CONF_D} /etc/conf.d/

  systemctl enable snapper-cleanup.timer
fi

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

rm -r $HOME/ArchTitus
rm -r /home/$USERNAME/ArchTitus

# Replace in the same state
cd $pwd
