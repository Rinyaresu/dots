{
  flake.modules.nixos.gui.key = "${__curPos.file}#nixos.files";
  flake.modules.nixos.gui.services.gvfs.enable = true;
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.files";
    home.packages = [ pkgs.nautilus ];
    dconf.settings."org/gnome/desktop/media-handling" = {
      automount = false;
      automount-open = false;
    };
  };
}
