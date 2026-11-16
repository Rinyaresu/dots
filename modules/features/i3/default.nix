{ config, ... }:
let
  lockCommand =
    pkgs:
    pkgs.writeShellScript "i3-lock" ''
      ${pkgs.coreutils}/bin/timeout 1s ${pkgs.dunst}/bin/dunstctl set-paused true || true
      ${pkgs.i3lock}/bin/i3lock --nofork --color=faf4ed &
      locker=$!
      trap 'if ! kill -0 "$locker" 2>/dev/null; then ${pkgs.coreutils}/bin/timeout 1s ${pkgs.dunst}/bin/dunstctl set-paused false || true; fi' EXIT
      if [[ -e /dev/fd/''${XSS_SLEEP_LOCK_FD:--1} ]]; then
        exec {XSS_SLEEP_LOCK_FD}<&-
      fi
      wait "$locker"
    '';
in
{
  flake.modules.nixos.i3 = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.i3";
    services.gnome.gnome-keyring.enable = true;
    services.gnome.gcr-ssh-agent.enable = false;
    services.xserver = {
      enable = true;
      windowManager.i3.enable = true;
      displayManager.startx = {
        enable = true;
        generateScript = true;
        extraCommands = ''
          cleanup() {
            ${pkgs.systemd}/bin/systemctl --user stop graphical-session.target graphical-session-pre.target
            DISPLAY= WAYLAND_DISPLAY= NIRI_SOCKET= XAUTHORITY= XDG_CURRENT_DESKTOP= XDG_SESSION_DESKTOP= XDG_SESSION_TYPE= \
              ${pkgs.dbus}/bin/dbus-update-activation-environment DISPLAY WAYLAND_DISPLAY NIRI_SOCKET XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
            ${pkgs.systemd}/bin/systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY NIRI_SOCKET XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
          }
          trap cleanup EXIT
          trap 'exit' TERM INT
          export XDG_CURRENT_DESKTOP=i3
          export XDG_SESSION_DESKTOP=i3
          export XDG_SESSION_TYPE=x11
          unset WAYLAND_DISPLAY NIRI_SOCKET
          ${pkgs.systemd}/bin/systemctl --user unset-environment WAYLAND_DISPLAY NIRI_SOCKET
          WAYLAND_DISPLAY= NIRI_SOCKET= ${pkgs.dbus}/bin/dbus-update-activation-environment WAYLAND_DISPLAY NIRI_SOCKET
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_SESSION_ID XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
          ${pkgs.xset}/bin/xset s noblank
          ${pkgs.xset}/bin/xset +dpms
          ${pkgs.xset}/bin/xset dpms 0 0 900
          ${pkgs.xsetroot}/bin/xsetroot -solid '#faf4ed'
        '';
      };
    };
  };

  flake.modules.homeManager.i3 =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    {
      key = "${__curPos.file}#homeManager.i3";
      imports = [ config.flake.modules.homeManager.ghostty ];
      assertions = [
        {
          assertion = osConfig.services.xserver.windowManager.i3.enable;
          message = "The i3 home configuration requires i3 on this host.";
        }
      ];
      dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-light";
      xsession.windowManager.i3 = {
        enable = true;
        config = {
          modifier = "Mod4";
          terminal = "${pkgs.ghostty}/bin/ghostty";
          keybindings = lib.mkOptionDefault {
            "Mod4+Mod1+l" = "exec ${pkgs.systemd}/bin/loginctl lock-session";
            "Mod4+Mod1+b" = "exec ${pkgs.setxkbmap}/bin/setxkbmap -layout br";
            "Mod4+Mod1+u" = "exec ${pkgs.setxkbmap}/bin/setxkbmap -layout us -variant intl";
          };
        };
      };
      programs.i3status = {
        enable = true;
        modules."tztime local".settings.format = "%x %H:%M";
      };
      services.screen-locker = {
        enable = true;
        inactiveInterval = 10;
        xautolock.enable = false;
        xss-lock.extraOptions = [ "--transfer-sleep-lock" ];
        lockCmd = "${lockCommand pkgs}";
      };
      systemd.user.services.xss-lock.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";
    };
}
