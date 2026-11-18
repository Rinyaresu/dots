{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.spotify";
    home.packages = [ pkgs.spotify ];
  };
}
