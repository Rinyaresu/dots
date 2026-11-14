{
  flake.modules.homeManager.stremio = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.stremio";
    home.packages = [ pkgs.stremio-linux-shell ];
  };
}
