{
  flake.modules.nixos.gui.services.gvfs.enable = true;
  flake.modules.homeManager.gui = { pkgs, ... }: {
    home.packages = [ pkgs.nautilus ];
    dconf.settings."org/gnome/desktop/media-handling" = {
      automount = false;
      automount-open = false;
    };
  };
}
