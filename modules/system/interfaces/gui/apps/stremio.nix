{ config, ... }:
{
  flake.modules.homeManager.stremio = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.stremio";
    home.packages = [ pkgs.stremio-linux-shell ];
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.stremio ];
  };
}
