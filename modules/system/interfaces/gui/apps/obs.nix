{ config, ... }:
{
  flake.modules.homeManager.obs = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.obs";
    home.packages = [ pkgs.obs-studio ];
  };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.obs ];
  };
}
