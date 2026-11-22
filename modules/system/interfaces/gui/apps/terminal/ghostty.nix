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
      cursor-style-blink = true;
      shell-integration-features = "no-cursor";
      window-padding-x = 0;
      window-padding-y = 0;
      background-opacity = 1.0;
      confirm-close-surface = false;
      window-decoration = "server";
      gtk-titlebar = false;
    };
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.ghostty ];
  };
}
