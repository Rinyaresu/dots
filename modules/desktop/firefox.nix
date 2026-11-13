{
  flake.modules.nixos.gui.xdg.mime.defaultApplications = {
    "application/pdf" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };
  flake.modules.homeManager.gui = { pkgs, ... }: {
    home.packages = [ pkgs.firefox ];
  };
}
