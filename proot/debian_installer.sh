#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "\e[31m[✘] Terjadi kesalahan. Proses dihentikan.\e[0m"' ERR

cyan="\e[36m"; green="\e[32m"; yellow="\e[33m"; red="\e[31m"; reset="\e[0m"

clear
echo -e "${cyan}╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮"
echo -e "│        🪟 DEBIAN GUI INSTALLER for Termux       │"
echo -e "╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯${reset}"

echo -e "${yellow}[•] Checking and installing key dependencies...${reset}"
apt-get clean
apt-get update -y &>/dev/null
apt-get upgrade -y --with-new-pkgs -o Dpkg::Options::="--force-confdef" &>/dev/null

for pkg in x11-repo pulseaudio termux-x11-nightly proot-distro; do
    command -v $pkg &>/dev/null || {
        echo -e "${cyan}  ↳ Install: ${pkg}...${reset}"
        pkg install -y $pkg &>/dev/null
    }
done

echo -e "${yellow}[•] Checking Debian...${reset}"
if [ -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
    echo -e "${green}[✔] Debian is already installed. Skipping installation.${reset}"
else
    echo -e "${yellow}[•] Installing Debian...${reset}"
    proot-distro install debian
fi

echo -e "${yellow}[•] Updating Debian system...${reset}"
proot-distro login debian -- bash -c "apt update -y &>/dev/null"

echo -e "${yellow}[•] Installing base packages on Debian...${reset}"
for pkg in sudo nano adduser; do
    proot-distro login debian -- bash -c "apt install -y $pkg &>/dev/null"
done

for pkg in sudo nano adduser; do
    command -v $pkg &>/dev/null || {
        echo -e "${cyan}  ↳ Install: ${pkg}...${reset}"
    proot-distro login debian -- bash -c "apt install -y $pkg &>/dev/null"
    }
done

read -p $'\e[36m[?] Enter a new username for Debian: \e[0m' username

echo -e "${yellow}[•] Adding user: ${username}${reset}"
proot-distro login debian -- bash -c "adduser $username"

echo -e "${yellow}[•] Adding a user to sudoers...${reset}"
proot-distro login debian -- bash -c "echo '$username ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

echo -e "${cyan}╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮"
echo -e "│ Select Desktop Environment: │"
echo -e "├─────────────────────────────┤"
echo -e "│ 1) XFCE                     │"
echo -e "│ 2) LXDE                     │"
echo -e "│ 3) Cinnamon                 │"
echo -e "│ 4) GNOME                    │"
echo -e "│ 5) KDE Plasma               │"
echo -e "╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯${reset}"
read -p $'\e[36m[?] Enter your choice: \e[0m' env_choice

case $env_choice in
    1)
        de_label="XFCE"
        de_packages="xfce4"
        ;;
    2)
        de_label="LXDE"
        de_packages="lxde"
        ;;
    3)
        de_label="Cinnamon"
        de_packages="cinnamon"
        ;;
    4)
        de_label="GNOME"
        de_packages="dbus-x11 nano gnome gnome-shell gnome-terminal gnome-tweaks gnome-software nautilus gnome-shell-extension-manager gedit tigervnc-tools gnupg2"
        ;;
    5)
        de_label="KDE Plasma"
        de_packages="kde-plasma-desktop"
        ;;
    *)
        echo -e "${red}[✘] Invalid selection. Process terminated..${reset}"
        exit 1
        ;;
esac

echo -e "${yellow}[•] Create a Debian installer script...${reset}"
proot-distro login debian -- bash -c "cat > /home/$username/installer-debian.sh" <<EOL
#!/usr/bin/env bash
set -euo pipefail

yellow="\\e[33m"; green="\\e[32m"; cyan="\\e[36m"; red="\\e[31m"; reset="\\e[0m"

echo -e "\${yellow}[•] Starting Desktop Environment installation...\${reset}"

packages=(
$(echo "$de_packages" | tr ' ' '\n')
)

for pkg in "\${packages[@]}"; do
    echo -ne "\r\${cyan}[•] Installing: \$pkg\ ${reset}"
    sudo apt-get -y -o Dpkg::Progress-Fancy="0" install "\$pkg"
done

echo -e "\n\${green}[✔] Desktop Environment installation complete.\${reset}"

if [ "$env_choice" = "4" ]; then
    echo -e "\${yellow}[•] Removed the annoying login1 from GNOME...\${reset}"
    sudo find /usr -type f -iname '*login1*' -exec rm -f {} +
fi

echo -e "\${yellow}[•] Restore sudoers configuration...\${reset}"
sudo sed -i 's|'"$username"' ALL=(ALL) NOPASSWD:ALL|'"$username"' ALL=(ALL:ALL) ALL|' /etc/sudoers

echo -e "\${yellow}[•] Removing the installer script...\${reset}"
rm -- "\$0"

echo -e "\${green}[✔] Configuration complete.\${reset}"
EOL

echo -e "${yellow}[•] Run the installer script as user: ${username}${reset}"
proot-distro login debian --user $username -- bash /home/$username/installer-debian.sh

echo -e "${green}[✔] Debian has been successfully configured.${reset}"

echo -e "${yellow}[•] Create a running script...${reset}"

cat <<EOF > debian.sh
#!/data/data/com.termux/files/usr/bin/bash

clear

echo -e "\e[1;90m╭━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╮\e[0m"
echo -e "\e[1;90m│                🪟 LEGREK DEV               │\e[0m"
echo -e "\e[1;90m│           Termux DEBIAN Launcher           │\e[0m"
echo -e "\e[1;90m╰━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╯\e[0m"

echo -e "\n\e[1;36m📦 Setting up the desktop environment ${de_label}...\e[0m"

kill -9 \$(pgrep -f "termux.x11") 2>/dev/null

echo -e "\e[1;32m🔊 Getting Started with PulseAudio...\e[0m"
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

echo -e "\e[1;34m📺 Setting up Termux X11...\e[0m"
export XDG_RUNTIME_DIR=\${TMPDIR}
termux-x11 :0 >/dev/null &

echo -e "\e[1;35m⏳ Waiting for X11 to activate...\e[0m"
sleep 3

echo -e "\e[1;36m🚪 Open the Termux X11...\e[0m"
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity > /dev/null 2>&1
sleep 1

echo -e "\e[1;36m🚀 Running Debian ${de_label}...\e[0m"

EOF

case $env_choice in
  1)  # XFCE
      echo "proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && su - $username -c \"env DISPLAY=:0 startxfce4\"'" >> debian.sh
      ;;
  2)  # LXDE
      echo "proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && su - $username -c \"env DISPLAY=:0 startlxde\"'" >> debian.sh
      ;;
  3)  # Cinnamon
      echo "proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && su - $username -c \"env DISPLAY=:0 cinnamon-session\"'" >> debian.sh
      ;;
  4)  # GNOME
      echo "proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && sudo service dbus start && su - $username -c \"env DISPLAY=:0 gnome-shell --x11\"'" >> debian.sh
      ;;
  5)  # KDE
      echo "proot-distro login debian --shared-tmp -- /bin/bash -c 'export PULSE_SERVER=127.0.0.1 && export XDG_RUNTIME_DIR=\${TMPDIR} && su - $username -c \"env DISPLAY=:0 startplasma-x11\"'" >> debian.sh
      ;;
esac

cat <<'EOF' >> debian.sh

echo -e "\e[1;90mTurning off Termux X11...\e[0m"
pkill -f "termux.x11" && echo -e "\n\e[1;32mTermux X11 is disabled.\e[0m" || echo -e "\e[1;33mTermux X11 is not active.\e[0m"

echo -e "\e[1;90mStopping PulseAudio...\e[0m"
pkill -f "pulseaudio" && echo -e "\n\e[1;32mPulseAudio is turned off.\e[0m" || echo -e "\e[1;33mPulseAudio is not active.\e[0m"

echo -e "\n\e[1;32mDebian session ${de_label} has completed.\e[0m"
exit 0
EOF

chmod +x debian.sh

echo -e "${green}[✔] The running script was successfully created.${reset}"
echo -e "${green}[ ! ] Run it with the command ./debian.sh${reset}"
