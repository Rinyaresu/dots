{
  flake.modules.homeManager.ghostty.key = "${__curPos.file}#homeManager.ghostty";
  flake.modules.homeManager.ghostty.programs.ghostty = {
    enable = true;
    settings = {
      theme = "Rose Pine Dawn";
      font-family = "Iosevka Nerd Font";
    };
  };
}
