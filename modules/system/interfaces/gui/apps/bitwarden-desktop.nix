{
  flake.modules.homeManager.desktop-personal = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.desktop-personal";
    home.packages = [ pkgs.bitwarden-desktop ];
  };
}
