# Simple prompt and window title

function fish_title
  echo (prompt_pwd)
end

function fish_prompt
  echo -n '❯ '
end


