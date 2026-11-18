{ config, ... }:
{
  flake.modules.homeManager.spotify = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.spotify";
    home.packages = [ pkgs.spotify ];
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.spotify ];
  };
}
