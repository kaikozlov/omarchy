# File system
alias ls="eza -lh --group-directories-first --icons=auto"
alias lsa="ls -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias lta="lt -a"
alias ff='fzf --preview "bat --style=numbers --color=always {}"'

# Use enhanced directory jumping by default
alias cd='zd'

# Directory movement abbreviations
abbr -a -- .. 'cd ..'
abbr -a -- ... 'cd ../..'
abbr -a -- .... 'cd ../../..'

# Tools
alias g='git'
alias d='docker'
alias r='rails'
function n
  if test (count $argv) -eq 0
    nvim .
  else
    nvim $argv
  end
end

# Git
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# Find packages without leaving the terminal
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"


