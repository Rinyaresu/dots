{ config, ... }:
{
  flake.modules.homeManager.base = {
    key = "${__curPos.file}#homeManager.providers";
    imports = [ config.flake.modules.homeManager.fish ];
    programs.mise = {
      enable = true;
      enableFishIntegration = true;
      globalConfig.settings = {
        auto_install = false;
        exec_auto_install = false;
        not_found_auto_install = false;
        task.run_auto_install = false;
        trusted_config_paths = [ ];
        idiomatic_version_file_enable_tools = [ ];
        ruby.compile = false;
        node.compile = false;
      };
    };
    programs.direnv = {
      enable = true;
      enableFishIntegration = true;
      mise.enable = false;
    };
  };
}
