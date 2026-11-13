{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    home.packages = [ pkgs.google-chrome ];
  };
}
