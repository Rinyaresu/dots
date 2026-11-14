{
  flake.modules.homeManager.discord = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.discord";
    home.packages = [ pkgs.discord ];
  };
}
