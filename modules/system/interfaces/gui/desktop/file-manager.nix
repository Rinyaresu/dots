{ config, ... }:
{
  flake.modules.nixos.files.key = "${__curPos.file}#nixos.files";
  flake.modules.nixos.files.services.gvfs.enable = true;
  flake.modules.homeManager.files = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.files";
    home.packages = [ pkgs.nautilus ];
    dconf.settings."org/gnome/desktop/media-handling" = {
      automount = false;
      automount-open = false;
    };
  };

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.files ];
  };
  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.files ];
  };
}
