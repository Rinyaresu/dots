{
  flake.modules.homeManager.gui = {
    programs.yazi = {
      enable = true;
      settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
      theme = {
        flavor.light = "rose-pine-dawn";
        flavor.dark = "rose-pine-dawn";
      };
      # The archive for the original d82f54f pin returns 404 on CI.
      flavors.rose-pine-dawn = ./rose-pine-dawn.yazi;
    };
  };
}
