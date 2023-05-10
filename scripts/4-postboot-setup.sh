#!/usr/bin/env bash
echo "Installing flatpak packages"
sudo pacman -S --noconfirm --needed flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
for i in "com.slack.Slack" "com.bitwarden.desktop" "com.github.iwalton3.jellyfin-media-player" "com.github.tchx84.Flatseal" "io.github.JaGoLi.ytdl_gui" "io.github.shiftey.Desktop" "md.obsidian.Obsidian" "org.zotero.Zotero"; do
  pkg="$(echo $i | awk -F- '{print $1}')"
  name="$(echo $i | awk -F- '{print $2}')"
  echo "INSTALLING: $name"
  sudo flatpak install flathub $pkg -y
done

# --Gnome only--
sudo flatpak install flathub "io.github.realmazharhussain.GdmSettings" -y

# Enable extensions
echo "Making gnome tweaks"
gnome-extensions enable auto-move-windows@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable drive-menu@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable places-menu@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable window-navigator@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com # Enable user-theme extension for shell theming
which pamac &>/dev/null && gnome-extensions enable pamac-updates@manjaro.org

# Apply theming
gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Pink-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-dracula-dark"
gsettings set org.gnome.shell.extensions.user-theme name "Orchis-Pink-Dark"

# Enable fractional scaling in wayland
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Applying tweaks/fixes
gsettings set org.gnome.desktop.default-applications.terminal exec 'gnome-terminal'
git clone https://github.com/Zackptg5/gnome-dash-fix
chmod +x gnome-dash-fix/interactive.py
./gnome-dash-fix/interactive.py

echo "Set font to 'MesloLGNS NF Regular' in Gnome Terminal before first launching it!"
echo -e "Here's 3rd party extensions I use (grab them from extensions.gnome.org):
AppIndicator
Caffeine
Dash to Dock
GSConnect
Improved OSK - only needed if you have a touchscreen
"
echo "You can also modify lockscreen settings with Login Manager Settings App"