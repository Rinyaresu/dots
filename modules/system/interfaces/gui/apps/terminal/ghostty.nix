{ config, ... }:
{
  flake.modules.homeManager.ghostty =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    {
      key = "${__curPos.file}#homeManager.ghostty";
      programs.ghostty = {
        enable = true;
        package = lib.mkIf (osConfig.networking.hostName == "desktop") (
          pkgs.symlinkJoin {
            pname = "ghostty";
            inherit (pkgs.ghostty) version meta;
            paths = [ pkgs.ghostty ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            passthru = { inherit (pkgs.ghostty) vim; };
            postBuild = ''
              rm "$out/bin/ghostty"
              makeWrapper ${lib.getExe pkgs.ghostty} "$out/bin/ghostty" --set GTK_IM_MODULE simple

              for file in \
                share/applications/com.mitchellh.ghostty.desktop \
                share/dbus-1/services/com.mitchellh.ghostty.service \
                share/systemd/user/app-com.mitchellh.ghostty.service
              do
                rm "$out/$file"
                substitute "${pkgs.ghostty}/$file" "$out/$file" \
                  --replace-fail "${lib.getExe pkgs.ghostty}" "$out/bin/ghostty"
              done
            '';
          }
        );
        settings = {
          theme = "Rose Pine Dawn";
          font-family = "IosevkaTerm Nerd Font";
          font-size = 15;
          adjust-cell-height = 1;
          cursor-style = "block";
          cursor-style-blink = true;
          shell-integration-features = "no-cursor";
          window-padding-x = 4;
          window-padding-y = 4;
          background-opacity = 1.0;
          confirm-close-surface = false;
          window-decoration = "server";
          gtk-titlebar = false;
        };
      };
    };

  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.ghostty ];
  };
}
