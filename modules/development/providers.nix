{
  flake.modules.homeManager.development = { pkgs, ... }: {
    programs.mise = {
      enable = true;
      enableFishIntegration = false;
      globalConfig.settings = {
        not_found_auto_install = false;
        ruby.compile = false;
        node.compile = false;
      };
    };
    home.packages = [ pkgs.direnv ];
    xdg.configFile."fish/conf.d/direnv.fish".text = "";
  };
}
