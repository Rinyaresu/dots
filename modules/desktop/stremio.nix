{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    home.packages = [ pkgs.stremio-linux-shell ];
  };
}
