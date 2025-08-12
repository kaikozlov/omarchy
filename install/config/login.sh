#!/bin/bash

# Hyprland launched via UWSM and login directly as user, rely on disk encryption + hyprlock for security
if ! command -v uwsm &>/dev/null || ! command -v plymouth &>/dev/null; then
  sudo pacman -U --noconfirm https://archive.archlinux.org/packages/u/uwsm/uwsm-0.23.0-1-any.pkg.tar.zst
  yay -S --noconfirm --needed plymouth
fi

# ==============================================================================
# PLYMOUTH SETUP
# ==============================================================================

if ! grep -Eq '^HOOKS=.*plymouth' /etc/mkinitcpio.conf; then
  # Backup original mkinitcpio.conf just in case
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.${backup_timestamp}"

  # Add plymouth to HOOKS array after 'base udev' or 'base systemd'
  if grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base systemd"; then
    sudo sed -i '/^HOOKS=/s/base systemd/base systemd plymouth/' /etc/mkinitcpio.conf
  elif grep "^HOOKS=" /etc/mkinitcpio.conf | grep -q "base udev"; then
    sudo sed -i '/^HOOKS=/s/base udev/base udev plymouth/' /etc/mkinitcpio.conf
  else
    echo "Couldn't add the Plymouth hook"
  fi

  # Regenerate initramfs
  sudo mkinitcpio -P
fi

# Add kernel parameters for Plymouth
if [ -d "/boot/loader/entries" ]; then # systemd-boot
  echo "Detected systemd-boot"

  for entry in /boot/loader/entries/*.conf; do
    if [ -f "$entry" ]; then
      # Skip fallback entries
      if [[ "$(basename "$entry")" == *"fallback"* ]]; then
        echo "Skipped: $(basename "$entry") (fallback entry)"
        continue
      fi

      # Skip if splash it already present for some reason
      if ! grep -q "splash" "$entry"; then
        sudo sed -i '/^options/ s/$/ splash quiet/' "$entry"
      else
        echo "Skipped: $(basename "$entry") (splash already present)"
      fi
    fi
  done
elif [ -f "/etc/default/grub" ]; then # Grub
  echo "Detected grub"

  # Backup GRUB config before modifying
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  sudo cp /etc/default/grub "/etc/default/grub.bak.${backup_timestamp}"

  # Check if splash is already in GRUB_CMDLINE_LINUX_DEFAULT
  if ! grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub; then
    # Get current GRUB_CMDLINE_LINUX_DEFAULT value
    current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)

    # Add splash and quiet if not present
    new_cmdline="$current_cmdline"
    if [[ ! "$current_cmdline" =~ splash ]]; then
      new_cmdline="$new_cmdline splash"
    fi
    if [[ ! "$current_cmdline" =~ quiet ]]; then
      new_cmdline="$new_cmdline quiet"
    fi

    # Trim any leading/trailing spaces
    new_cmdline=$(echo "$new_cmdline" | xargs)

    sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"/" /etc/default/grub

    # Regenerate grub config
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
    echo "GRUB already configured with splash kernel parameters"
  fi
elif [ -d "/etc/cmdline.d" ]; then # UKI
  echo "Detected a UKI setup"
  # Relying on mkinitcpio to assemble a UKI
  # https://wiki.archlinux.org/title/Unified_kernel_image
  if ! grep -q splash /etc/cmdline.d/*.conf; then
    # Need splash, create the omarchy file
    echo "splash" | sudo tee -a /etc/cmdline.d/omarchy.conf
  fi
  if ! grep -q quiet /etc/cmdline.d/*.conf; then
    # Need quiet, create or append the omarchy file
    echo "quiet" | sudo tee -a /etc/cmdline.d/omarchy.conf
  fi
elif [ -f "/etc/kernel/cmdline" ]; then # UKI Alternate
  # Alternate UKI kernel cmdline location
  echo "Detected a UKI setup"

  # Backup kernel cmdline config before modifying
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  sudo cp /etc/kernel/cmdline "/etc/kernel/cmdline.bak.${backup_timestamp}"

  current_cmdline=$(cat /etc/kernel/cmdline)

  # Add splash and quiet if not present
  new_cmdline="$current_cmdline"
  if [[ ! "$current_cmdline" =~ splash ]]; then
    new_cmdline="$new_cmdline splash"
  fi
  if [[ ! "$current_cmdline" =~ quiet ]]; then
    new_cmdline="$new_cmdline quiet"
  fi

  # Trim any leading/trailing spaces
  new_cmdline=$(echo "$new_cmdline" | xargs)

  # Write new file
  echo $new_cmdline | sudo tee /etc/kernel/cmdline
else
  echo ""
  echo " None of systemd-boot, GRUB, or UKI detected. Please manually add these kernel parameters:"
  echo "  - splash (to see the graphical splash screen)"
  echo "  - quiet (for silent boot)"
  echo ""
fi

if [ "$(plymouth-set-default-theme)" != "omarchy" ]; then
  sudo cp -r "$HOME/.local/share/omarchy/default/plymouth" /usr/share/plymouth/themes/omarchy/
  sudo plymouth-set-default-theme -R omarchy
fi

## ==============================================================================
## LOGIN METHOD SELECTION
## ==============================================================================

if gum confirm "Use LY TUI display manager on TTY1 instead of seamless auto-login?"; then
  # ==============================================================================
  # LY DISPLAY MANAGER (TTY1)
  # ==============================================================================

  # Install ly if needed
  if ! command -v ly-dm &>/dev/null; then
    yay -S --noconfirm --needed ly
  fi

  # Provide ly.service (explicitly ensure TTY1)
  sudo mkdir -p /etc/systemd/system
  cat <<'LYUNIT' | sudo tee /etc/systemd/system/ly.service >/dev/null
[Unit]
Description=TUI display manager
After=systemd-user-sessions.service plymouth-quit-wait.service
After=getty@tty1.service
Conflicts=getty@tty1.service

[Service]
Type=idle
ExecStart=/usr/bin/ly-dm
StandardInput=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes

[Install]
Alias=display-manager.service
LYUNIT

  # Write Ly configuration
  sudo mkdir -p /etc/ly
  sudo tee /etc/ly/config.ini >/dev/null <<'LYCONF'
# Ly supports 24-bit true color with styling, which means each color is a 32-bit value.
# The format is 0xSSRRGGBB, where SS is the styling, RR is red, GG is green, and BB is blue.
# Here are the possible styling options:
#define TB_BOLD      0x01000000
#define TB_UNDERLINE 0x02000000
#define TB_REVERSE   0x04000000
#define TB_ITALIC    0x08000000
#define TB_BLINK     0x10000000
#define TB_HI_BLACK  0x20000000
#define TB_BRIGHT    0x40000000
#define TB_DIM       0x80000000
# Programmatically, you'd apply them using the bitwise OR operator (|), but because Ly's
# configuration doesn't support using it, you have to manually compute the color value.
# Note that, if you want to use the default color value of the terminal, you can use the
# special value 0x00000000. This means that, if you want to use black, you *must* use
# the styling option TB_HI_BLACK (the RGB values are ignored when using this option).

# Allow empty password or not when authenticating
allow_empty_password = false

# The active animation
# none     -> Nothing
# doom     -> PSX DOOM fire
# matrix   -> CMatrix
# colormix -> Color mixing shader
animation = colormix

# Stop the animation after some time
# 0 -> Run forever
# 1..2e12 -> Stop the animation after this many seconds
animation_timeout_sec = 0

# The character used to mask the password
# You can either type it directly as a UTF-8 character (like *), or use a UTF-32
# codepoint (for example 0x2022 for a bullet point)
# If null, the password will be hidden
# Note: you can use a # by escaping it like so: \#
asterisk = *

# The number of failed authentications before a special animation is played... ;)
auth_fails = 10

# Background color id
bg = 0x00000000

# Change the state and language of the big clock
# none -> Disabled (default)
# en   -> English
# fa   -> Farsi
bigclock = en

# Blank main box background
# Setting to false will make it transparent
blank_box = true

# Border foreground color id
border_fg = 0x00FFFFFF

# Title to show at the top of the main box
# If set to null, none will be shown
box_title = null

# Brightness increase command
brightness_down_cmd = /usr/bin/brightnessctl -q s 10%-

# Brightness decrease key, or null to disable
brightness_down_key = F5

# Brightness increase command
brightness_up_cmd = /usr/bin/brightnessctl -q s +10%

# Brightness increase key, or null to disable
brightness_up_key = F6

# Erase password input on failure
clear_password = false

# Format string for clock in top right corner (see strftime specification). Example: %c
# If null, the clock won't be shown
clock = null

# CMatrix animation foreground color id
cmatrix_fg = 0x0000FF00

# CMatrix animation minimum codepoint. It uses a 16-bit integer
# For Japanese characters for example, you can use 0x3000 here
cmatrix_min_codepoint = 0x21

# CMatrix animation maximum codepoint. It uses a 16-bit integer
# For Japanese characters for example, you can use 0x30FF here
cmatrix_max_codepoint = 0x7B

# Color mixing animation first color id
colormix_col1 = 0x00FF0000

# Color mixing animation second color id
colormix_col2 = 0x000000FF

# Color mixing animation third color id
colormix_col3 = 0x20000000

# Console path
console_dev = /dev/console

# Input box active by default on startup
# Available inputs: info_line, session, login, password
default_input = login

# DOOM animation top color (low intensity flames)
doom_top_color = 0x00FF0000

# DOOM animation middle color (medium intensity flames)
doom_middle_color = 0x00FFFF00

# DOOM animation bottom color (high intensity flames)
doom_bottom_color = 0x00FFFFFF

# Error background color id
error_bg = 0x00000000

# Error foreground color id
# Default is red and bold
error_fg = 0x01FF0000

# Foreground color id
fg = 0x00FFFFFF

# Remove main box borders
hide_borders = false

# Remove power management command hints
hide_key_hints = false

# Initial text to show on the info line
# If set to null, the info line defaults to the hostname
initial_info_text = null

# Input boxes length
input_len = 34

# Active language
# Available languages are found in /etc/ly/lang/
lang = en

# Load the saved desktop and username
load = true

# Command executed when logging in
# If null, no command will be executed
# Important: the code itself must end with `exec "$@"` in order to launch the session!
# You can also set environment variables in there, they'll persist until logout
login_cmd = null

# Command executed when logging out
# If null, no command will be executed
# Important: the session will already be terminated when this command is executed, so
# no need to add `exec "$@"` at the end
logout_cmd = null

# Main box horizontal margin
margin_box_h = 2

# Main box vertical margin
margin_box_v = 1

# Event timeout in milliseconds
min_refresh_delta = 5

# Set numlock on/off at startup
numlock = false

# Default path
# If null, ly doesn't set a path
path = /sbin:/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

# Command executed when pressing restart_key
restart_cmd = /sbin/shutdown -r now

# Specifies the key used for restart (F1-F12)
restart_key = F2

# Save the current desktop and login as defaults
save = true

# Service name (set to ly to use the provided pam config file)
service_name = ly

# Session log file path
# This will contain stdout and stderr of Wayland sessions
# By default it's saved in the user's home directory
# Important: due to technical limitations, X11 and shell sessions aren't supported, which
# means you won't get any logs from those sessions
session_log = ly-session.log

# Setup command
setup_cmd = /etc/ly/setup.sh

# Command executed when pressing shutdown_key
shutdown_cmd = /sbin/shutdown -a now

# Specifies the key used for shutdown (F1-F12)
shutdown_key = F1

# Command executed when pressing sleep key (can be null)
sleep_cmd = null

# Specifies the key used for sleep (F1-F12)
sleep_key = F3

# Center the session name.
text_in_center = false

# TTY in use
tty = 1

# Default vi mode
# normal   -> normal mode
# insert   -> insert mode
vi_default_mode = normal

# Enable vi keybindings
vi_mode = false

# Wayland desktop environments
# You can specify multiple directories,
# e.g. /usr/share/wayland-sessions:/usr/local/share/wayland-sessions
waylandsessions = /usr/share/wayland-sessions

# Xorg server command
x_cmd = /usr/bin/X

# Xorg xauthority edition tool
xauth_cmd = /usr/bin/xauth

# xinitrc
# If null, the xinitrc session will be hidden
xinitrc = ~/.xinitrc

# Xorg desktop environments
# You can specify multiple directories,
# e.g. /usr/share/xsessions:/usr/local/share/xsessions
xsessions = /usr/share/xsessions
LYCONF
  sudo chmod 644 /etc/ly/config.ini

  # Ensure plymouth quit wait is available (not masked)
  if systemctl is-enabled plymouth-quit-wait.service | grep -q masked; then
    sudo systemctl unmask plymouth-quit-wait.service
  fi

  # Remove plymouth override that holds splash until graphical.target (not needed with LY)
  if [ -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf ]; then
    sudo rm -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf
  fi

  # Disable seamless auto-login service if present
  if systemctl list-unit-files | grep -q '^omarchy-seamless-login.service'; then
    if systemctl is-enabled omarchy-seamless-login.service | grep -q enabled; then
      sudo systemctl disable --now omarchy-seamless-login.service
    fi
  fi

  # Disable getty@tty1 to give control to LY
  if ! systemctl is-enabled getty@tty1.service | grep -q disabled; then
    sudo systemctl disable getty@tty1.service
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable ly.service

else
  # ==============================================================================
  # SEAMLESS LOGIN (AUTO-LOGIN DIRECTLY TO HYPRLAND VIA UWSM ON TTY1)
  # ==============================================================================

  if [ ! -x /usr/local/bin/seamless-login ]; then
    # Compile the seamless login helper -- needed to prevent seeing terminal between loader and desktop
    cat <<'CCODE' >/tmp/seamless-login.c
/*
* Seamless Login - Minimal SDDM-style Plymouth transition
* Replicates SDDM's VT management for seamless auto-login
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/kd.h>
#include <linux/vt.h>
#include <sys/wait.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int vt_fd;
    int vt_num = 1; // TTY1
    char vt_path[32];
    
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <session_command>\n", argv[0]);
        return 1;
    }
    
    // Open the VT (simple approach like SDDM)
    snprintf(vt_path, sizeof(vt_path), "/dev/tty%d", vt_num);
    vt_fd = open(vt_path, O_RDWR);
    if (vt_fd < 0) {
        perror("Failed to open VT");
        return 1;
    }
    
    // Activate the VT
    if (ioctl(vt_fd, VT_ACTIVATE, vt_num) < 0) {
        perror("VT_ACTIVATE failed");
        close(vt_fd);
        return 1;
    }
    
    // Wait for VT to be active
    if (ioctl(vt_fd, VT_WAITACTIVE, vt_num) < 0) {
        perror("VT_WAITACTIVE failed");
        close(vt_fd);
        return 1;
    }
    
    // Critical: Set graphics mode to prevent console text
    if (ioctl(vt_fd, KDSETMODE, KD_GRAPHICS) < 0) {
        perror("KDSETMODE KD_GRAPHICS failed");
        close(vt_fd);
        return 1;
    }
    
    // Clear VT and close (like SDDM does)
    const char *clear_seq = "\33[H\33[2J";
    if (write(vt_fd, clear_seq, strlen(clear_seq)) < 0) {
        perror("Failed to clear VT");
    }
    
    close(vt_fd);
    
    // Set working directory to user's home
    const char *home = getenv("HOME");
    if (home) chdir(home);
    
    // Now execute the session command
    execvp(argv[1], &argv[1]);
    perror("Failed to exec session");
    return 1;
}
CCODE

    gcc -o /tmp/seamless-login /tmp/seamless-login.c
    sudo mv /tmp/seamless-login /usr/local/bin/seamless-login
    sudo chmod +x /usr/local/bin/seamless-login
    rm /tmp/seamless-login.c
  fi

  if [ ! -f /etc/systemd/system/omarchy-seamless-login.service ]; then
    cat <<EOF | sudo tee /etc/systemd/system/omarchy-seamless-login.service
[Unit]
Description=Omarchy Seamless Auto-Login
Documentation=https://github.com/basecamp/omarchy
Conflicts=getty@tty1.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
PartOf=graphical.target

[Service]
Type=simple
ExecStart=/usr/local/bin/seamless-login uwsm start -- hyprland.desktop
Restart=always
RestartSec=2
User=$USER
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal+console
PAMName=login

[Install]
WantedBy=graphical.target
EOF
  fi

  if [ ! -f /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf ]; then
    # Make plymouth remain until graphical.target
    sudo mkdir -p /etc/systemd/system/plymouth-quit.service.d
    sudo tee /etc/systemd/system/plymouth-quit.service.d/wait-for-graphical.conf <<'EOF'
[Unit]
After=multi-user.target
EOF
  fi

  # Mask plymouth-quit-wait.service only if not already masked
  if ! systemctl is-enabled plymouth-quit-wait.service | grep -q masked; then
    sudo systemctl mask plymouth-quit-wait.service
    sudo systemctl daemon-reload
  fi

  # Enable omarchy-seamless-login.service only if not already enabled
  if ! systemctl is-enabled omarchy-seamless-login.service | grep -q enabled; then
    sudo systemctl enable omarchy-seamless-login.service
  fi

  # Disable getty@tty1.service only if not already disabled
  if ! systemctl is-enabled getty@tty1.service | grep -q disabled; then
    sudo systemctl disable getty@tty1.service
  fi
fi
