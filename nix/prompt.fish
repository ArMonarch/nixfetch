if not functions -q __nix_upstream_prompt
  if functions -q fish_prompt
    functions --copy fish_prompt __nix_upstream_prompt
  else
    function __nix_upstream_prompt
      printf "%s> " (prompt_pwd)
    end
  end
end

function fish_prompt
  set_color -o blue
  printf '(nix) '
  set_color normal
  __nix_upstream_prompt
end
