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

Installing AUR Softwares
"
source $HOME/ArchTitus/configs/setup.conf

cd ~
mkdir "/home/$USERNAME/.cache"
touch "/home/$USERNAME/.cache/zshhistory"
git clone "https://github.com/ChrisTitusTech/zsh"
# Zsh doesn't read inputrc and so some keys like 'del' won't work right. Add keybindings
echo "$(sed -n 's/^/bindkey /; s/: / /p' /etc/inputrc)" >> zsh/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
ln -s ~/zsh/.zshrc ~/.zshrc
sudo chsh -s $(which zsh) $(whoami) 
# Change editor to nano
sed -i "s/EDITOR=.*/EDITOR=nano/" zsh/.zshrc
sed -i "s/EDITOR=.*/EDITOR=nano/" zsh/aliasrc

# Install DE
sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}.txt
if [[ $DESKTOP_ENV == "gnome" ]] && [[ ${AUR_HELPER} == "pamac" ]]; then
  sudo pacman -Rdd --noconfirm gnome-software
fi

# Add Chaotic AUR
echo "Adding Chaotic AUR"
sudo pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key FBA220DFC880C036
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
sudo bash -c "echo -e \"[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\" >> /etc/pacman.conf"
sudo pacman -Sy
sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/chaoticaur-pkgs.txt

if [[ -f "$HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-chaoticaur.txt" ]]; then
  sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-chaoticaur.txt
fi

if [[ ${AUR_HELPER} != "none" ]]; then
  sudo pacman -S yay --noconfirm --needed # Use yay temporarily - pamac doesn't work right during install
  if [[ ${AUR_HELPER} == "pamac" ]]; then
    sudo pacman -Rdd --noconfirm archlinux-appstream-data
    sudo pacman -S --noconfirm archlinux-appstream-data-pamac pamac-nosnap # Replace default with pamac
  fi
  yay -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/aur-pkgs.txt

  # Add advcpmv alias
  sed -i -e "s/alias cp=.*/alias cp='advcp -g'/" -e "s/alias mv=.*/alias mv='advmv -g'/" ~/zsh/aliasrc

  sudo ln -sf /usr/share/plymouth/themes/arch-breeze/logo_symb_blue.png /usr/share/plymouth/themes/arch-breeze/logo.png
fi

# Install virtualization packages if chosen
if [[ $VIRT == "true" ]]; then
  sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/virtualization.txt
fi

if [[ ${AUR_HELPER} == "pamac" ]]; then
  sudo pacman -Rs --noconfirm yay
fi

# Theming DE
export PATH=$PATH:~/.local/bin
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  sudo ln -sf /usr/share/plymouth/themes/arch-breeze/logo_symb_white.png /usr/share/plymouth/themes/arch-breeze/logo.png
  pip install konsave
  konsave -i ~/ArchTitus/configs/kde.knsv
  sleep 1
  konsave -a kde
fi

# Easyeffects Profiles
mkdir -p $HOME/.var/app/com.github.wwmm.pulseeffects/easyeffects/output
echo 1 | bash -c "$(curl -fsSL https://raw.githubusercontent.com/JackHack96/PulseEffects-Presets/master/install.sh)"

# Autostart syncthing
mkdir -p $HOME/.config/autostart
cp -f /usr/bin/syncthing $HOME/.config/autostart/syncthing

# Firefox touchscreen scrolling fix
[ -f /etc/security/pam_env.conf ] && sudo bash -c 'echo "MOZ_USE_XINPUT2 DEFAULT=1" >> /etc/security/pam_env.conf' || sudo bash -c 'echo "MOZ_USE_XINPUT2 DEFAULT=1" >> /usr/share/security/pam_env.conf'

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
