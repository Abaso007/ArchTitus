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
"
source $HOME/ArchTitus/configs/setup.conf
echo -ne "
-------------------------------------------------------------------------
                    Network Setup 
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed networkmanager dhclient
systemctl enable --now NetworkManager
echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors for optimal download 
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed pacman-contrib curl
pacman -S --noconfirm --needed reflector rsync arch-install-scripts git grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=$(grep -c ^processor /proc/cpuinfo)
echo -ne "
-------------------------------------------------------------------------
                    You have " $nc" cores. And
			changing the makeflags for "$nc" cores. Aswell as
				changing the compression settings.
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTAL_MEM -gt 8000000 ]]; then
	sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
	sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Setup Language to US and set locale  
-------------------------------------------------------------------------
"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"
timedatectl --no-ask-password set-timezone ${TIMEZONE}
timedatectl --no-ask-password set-ntp 1
ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
# Set keymaps
localectl --no-ask-password set-keymap ${KEYMAP}

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

#Add parallel downloading
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

#Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed

echo -ne "
-------------------------------------------------------------------------
                    Installing Base System  
-------------------------------------------------------------------------
"
if [[ ${DESKTOP_ENV} != "server" ]]; then
  pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/pacman-pkgs.txt
fi
echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"
# determine processor type and install microcode
proc_type=$(lscpu)
if grep -E "GenuineIntel" <<< ${proc_type}; then
	echo "Installing Intel microcode"
	echo microcode=intel-ucode.img >> $CONFIGS_DIR/setup.conf
	pacman -S --noconfirm --needed intel-ucode
	proc_ucode=intel-ucode.img
elif grep -E "AuthenticAMD" <<< ${proc_type}; then
	echo "Installing AMD microcode"
	echo microcode=amd-ucode.img >> $CONFIGS_DIR/setup.conf
	pacman -S --noconfirm --needed amd-ucode
	proc_ucode=amd-ucode.img
fi

echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"
# Graphics Drivers find and install
gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
	pacman -S --noconfirm --needed nvidia
	nvidia-xconfig
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
	pacman -S --noconfirm --needed xf86-video-amdgpu
elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
	pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
	pacman -S --needed --noconfirm libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
fi

echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
if [ $(whoami) = "root" ]; then
	groupadd libvirt
	useradd -m -G wheel,libvirt -s /bin/bash $USERNAME 
	echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"

	# use chpasswd to enter $USERNAME:$password
	echo "$USERNAME:$PASSWORD" | chpasswd
	echo "$USERNAME password set"

	cp -R $HOME/ArchTitus /home/$USERNAME/
	chown -R $USERNAME: /home/$USERNAME/ArchTitus
	echo "ArchTitus copied to home directory"

	# enter $NAME_OF_MACHINE to /etc/hostname
	echo $NAME_OF_MACHINE > /etc/hostname
else
	echo "You are already a user proceed with aur installs"
fi
if [[ ${FS} == "luks" ]]; then
	# Making sure to edit mkinitcpio conf if luks is selected
	# add encrypt in mkinitcpio.conf before filesystems in hooks
	sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
	# making mkinitcpio with linux kernel
	mkinitcpio -P
fi
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
"
