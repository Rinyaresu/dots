{ config, ... }:
{
  flake.modules.homeManager.ghostty.key = "${__curPos.file}#homeManager.ghostty";
  flake.modules.homeManager.ghostty.programs.ghostty = {
    enable = true;
    settings = {
      theme = "Rose Pine Dawn";
      font-family = "IosevkaTerm Nerd Font";
      font-size = 15;
      adjust-cell-height = 1;
      cursor-style = "block";
      cursor-style-blink = false;
      window-padding-x = 4;
      window-padding-y = 4;
    };
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.ghostty ];
  };
}
