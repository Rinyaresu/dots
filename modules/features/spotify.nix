{
  flake.modules.homeManager.spotify = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.spotify";
    home.packages = [ pkgs.spotify ];
  };
}
