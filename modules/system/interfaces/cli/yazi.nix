{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    programs.yazi = {
      enable = true;
      settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
      theme = {
        flavor.light = "rose-pine-dawn";
        flavor.dark = "rose-pine-dawn";
      };
      flavors.rose-pine-dawn = pkgs.fetchFromGitHub {
        owner = "Mintass";
        repo = "rose-pine-dawn.yazi";
        rev = "d82f54f7c646352dc03bfc5c849afaf5b8b79";
        hash = "sha256-/9GSE71gNohHqdhYCeGyaPnmVGs7zUkPD1MgC8hTvdA=";
      };
    };
  };
}
