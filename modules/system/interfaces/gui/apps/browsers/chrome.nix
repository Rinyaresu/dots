{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.chrome";
    home.packages = [ pkgs.google-chrome ];
  };

  flake.modules.homeManager.desktop-personal = { pkgs, ... }: {
    home.sessionVariables.BROWSER_BIN = "${pkgs.google-chrome}/bin/google-chrome";
  };
}
