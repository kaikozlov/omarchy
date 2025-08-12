echo "Update brave-browser.desktop to ensure we are always using wayland"
if [[ ! -f ~/.local/share/applications/brave-browser.desktop ]]; then
  cp ~/.local/share/omarchy/applications/brave-browser.desktop ~/.local/share/applications/
  xdg-settings set default-web-browser brave-browser.desktop
  xdg-mime default brave-browser.desktop x-scheme-handler/http
  xdg-mime default brave-browser.desktop x-scheme-handler/https
fi
