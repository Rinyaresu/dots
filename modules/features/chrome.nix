{
  flake.modules.homeManager.chrome = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.chrome";
    home.packages = [ pkgs.google-chrome ];
  };
}
