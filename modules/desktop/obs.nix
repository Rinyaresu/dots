{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    home.packages = [ pkgs.obs-studio ];
  };
}
