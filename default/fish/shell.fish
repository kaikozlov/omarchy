# Environment and PATH setup for Fish

# Add Omarchy and local bin directories to PATH (session-only)
set -gx PATH ./bin $HOME/.local/bin $HOME/.local/share/omarchy/bin $PATH

# Omarchy path
set -gx OMARCHY_PATH "$HOME/.local/share/omarchy"


