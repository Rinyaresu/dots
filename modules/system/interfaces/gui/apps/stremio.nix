{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.stremio";
    home.packages = [ pkgs.stremio-linux-shell ];
  };
}
