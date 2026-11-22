{ config, lib, ... }:
let
  hosts = config.flake.nixosConfigurations;
  system = hosts.desktop.config;
  home = system.home-manager.users.rinyaresu;
  labHome = hosts.lab.config.home-manager.users.rinyaresu;
  capture = lib.findFirst (
    package: (package.name or "") == "niri-screenshot"
  ) null home.home.packages;
in
{
  perSystem = { pkgs, ... }: {
    checks.graphical-behavior =
      pkgs.runCommand "graphical-behavior" { nativeBuildInputs = [ pkgs.python3 ]; }
        ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          python ${../../checks/graphical-behavior.py} \
            --capture ${capture}/bin/niri-screenshot \
            --lock ${home.services.screen-locker.lockCmd} \
            --session ${pkgs.writeText "startx-extra" system.services.xserver.displayManager.startx.extraCommands} \
            --noctalia ${home.xdg.configFile."noctalia/config.toml".source} \
            --tools ${
              pkgs.writeText "graphical-tools.json" (
                builtins.toJSON {
                  slurp = "${pkgs.slurp}/bin/slurp";
                  grim = "${pkgs.grim}/bin/grim";
                  satty = "${pkgs.satty}/bin/satty";
                  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
                  dunstctl = "${pkgs.dunst}/bin/dunstctl";
                  i3lock = "${pkgs.i3lock}/bin/i3lock";
                  systemctl = "${pkgs.systemd}/bin/systemctl";
                  dbus-update-activation-environment = "${pkgs.dbus}/bin/dbus-update-activation-environment";
                  xset = "${pkgs.xset}/bin/xset";
                  xsetroot = "${pkgs.xsetroot}/bin/xsetroot";
                }
              )
            }
          touch "$out"
        '';
    checks.graphical-config = pkgs.runCommand "graphical-config" { } ''
      grep -F 'Mod+Return { spawn "${lib.getExe home.programs.ghostty.package}"; }' ${
        home.xdg.configFile."niri/config.kdl".source
      }
      grep -F 'bindsym Mod4+Return exec ${lib.getExe home.programs.ghostty.package}' ${
        home.xdg.configFile."i3/config".source
      }
      export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_STATE_HOME="$TMPDIR/state"
      mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
      ${pkgs.niri}/bin/niri validate --config ${home.xdg.configFile."niri/config.kdl".source}
      ${pkgs.niri}/bin/niri validate --config ${labHome.xdg.configFile."niri/config.kdl".source}
      DBUS_SESSION_BUS_ADDRESS=1 ${home.xsession.windowManager.i3.package}/bin/i3 -C -c ${
        home.xdg.configFile."i3/config".source
      }
      ${lib.getExe home.programs.ghostty.package} +validate-config --config-file=${
        home.xdg.configFile."ghostty/config".source
      }
      ${pkgs.noctalia}/bin/noctalia config validate ${
        home.xdg.configFile."noctalia/config.toml".source
      } > validation.log 2>&1
      cat validation.log
      if grep -q WARN validation.log; then exit 1; fi
      touch "$out"
    '';
  };
}
