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
  if [[ "${FS}" == "btrfs" ]]; then
    root="LABEL=ROOT"
  elif [[ "${FS}" == "luks" ]]; then
    root="/dev/mapper/ROOT"
  fi
  bootctl install --esp-path=/boot
  echo -ne "
default arch.conf
timeout 3
console-mode max
editor no
  " > /boot/loader/loader.conf
  # linux
  echo -ne "
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=$root rootflags=subvol=@ rw" > /boot/loader/entries/arch.conf
  # linux-fallback
  echo -ne "
title Arch Linux (fallback initramfs)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=$root rootflags=subvol=@ rw" > /boot/loader/entries/arch-fallback.conf
  # linux-lts
  echo -ne "
title Arch Linux LTS
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts.img
options root=$root rootflags=subvol=@ rw" > /boot/loader/entries/arch-lts.conf
  # linux-lts-fallback
  echo -ne "
title Arch Linux LTS
linux /vmlinuz-linux-lts
initrd /initramfs-linux-lts-fallback.img
options root=$root rootflags=subvol=@ rw" > /boot/loader/entries/arch-lts-fallback.conf
curl -LJO https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
  for i in /boot/loader/entries/*.conf; do
    if [[ "${FS}" == "luks" ]]; then
      sed -i "s|options |options cryptdevice=UUID=$ENCRYPTED_PARTITION_UUID:ROOT:allow-discards rd.luks.options=discard |" $i
    fi 
    if [[ "$microcode" ]]; then
      sed -i "1i|initramfs-linux|initrd /$microcode.img|" $i
    fi
    if $SWAPFILE; then
      tmp="$(./btrfs_map_physical /swap/swapfile | head -n2 | tail -n1 | awk '{print $6}')"
      sed -i "s|rw|rw resume=$root resume_offset=$tmp / $(getconf PAGESIZE)|" $i
    fi
  done
  rm btrfs_map_physical.c btrfs_map_physical
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Plymouth Boot Splash
-------------------------------------------------------------------------
"
if  [[ ${FS} == "luks" ]]; then
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
  sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf # create plymouth-encrypt after block hook
else
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
fi
plymouth-set-default-theme -R bgrt

echo -ne "
-------------------------------------------------------------------------
                    Enabling Login Display Manager
-------------------------------------------------------------------------
"
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  systemctl disable sddm.service
  systemctl enable sddm-plymouth.service
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
mv -f /home/$USERNAME/ArchTitus/scripts/4-postboot-setup.sh /home/$USERNAME/4-postboot-setup.sh
if [[ $DESKTOP_ENV != "gnome" ]]; then
  sed -i '/--Gnome only--/,$d' /home/$USERNAME/4-postboot-setup.sh
fi
rm -r /home/$USERNAME/ArchTitus

# Replace in the same state
cd $pwd
