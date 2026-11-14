{
  flake.modules.homeManager.obs = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.obs";
    home.packages = [ pkgs.obs-studio ];
  };
}
