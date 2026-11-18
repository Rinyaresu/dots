{
  flake.modules.nixos.gui.key = "${__curPos.file}#nixos.firefox";
  flake.modules.nixos.gui.xdg.mime.defaultApplications = {
    "application/pdf" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };
  flake.modules.homeManager.gui = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.firefox";
    home.packages = [ pkgs.firefox ];
  };
}
