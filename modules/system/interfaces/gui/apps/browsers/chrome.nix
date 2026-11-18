{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.chrome";
    home.packages = [ pkgs.google-chrome ];
  };
}
