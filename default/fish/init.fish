# Initialize optional tools for Fish if present

if type -q mise
  mise activate fish | source
end

if type -q zoxide
  zoxide init fish | source
end

if type -q fzf
  if test -f /usr/share/fzf/completion.fish
    source /usr/share/fzf/completion.fish
  end
  if test -f /usr/share/fzf/key-bindings.fish
    source /usr/share/fzf/key-bindings.fish
  end
end


