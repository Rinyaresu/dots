{
  flake.modules.homeManager.git = { config, pkgs, ... }: {
    key = "${__curPos.file}#homeManager.git";
    home.packages = [ pkgs.lazygit ];
    home.file.".gitmessage".source = ./gitmessage;

    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        push.default = "simple";
        commit.template = "${config.home.homeDirectory}/.gitmessage";
        url."git@github.com:".insteadOf = "https://github.com/";
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        light = true;
        navigate = true;
      };
    };
  };
}
