{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.obs";
    home.packages = [ pkgs.obs-studio ];
  };
}
