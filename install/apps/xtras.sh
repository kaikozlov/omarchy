#!/bin/bash

if [ -z "$OMARCHY_BARE" ]; then
  yay -S --noconfirm --needed \
    gnome-calculator signal-desktop \
    obsidian-bin libreoffice obs-studio kdenlive \
    xournalpp localsend-bin # gnome-keyring

  # Packages known to be flaky or having key signing issues are run one-by-one
  for pkg in pinta spotify-launcher; do #zoom typora
    yay -S --noconfirm --needed "$pkg" ||
      echo -e "\e[31mFailed to install $pkg. Continuing without!\e[0m"
  done

  # yay -S --noconfirm --needed 1password-beta 1password-cli ||
  #   echo -e "\e[31mFailed to install 1password. Continuing without!\e[0m"
fi

# Copy over Omarchy applications
source omarchy-refresh-applications || true
