{ config, ... }:
{
  flake.modules.homeManager.chrome = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.chrome";
    home.packages = [ pkgs.google-chrome ];
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.chrome ];
  };
}
