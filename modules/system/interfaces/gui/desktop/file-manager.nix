{
  flake.modules.nixos.gui.key = "${__curPos.file}#nixos.files";
  flake.modules.nixos.gui.services.gvfs.enable = true;
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.files";
    home.packages = with pkgs; [
      nautilus
      vlc
      qbittorrent
    ];
    dconf.settings."org/gnome/desktop/media-handling" = {
      automount = true;
      automount-open = false;
    };
  };
}
