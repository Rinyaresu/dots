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
    services.xserver = {
      enable = true;
      windowManager.i3.enable = true;
      displayManager.startx = {
        enable = true;
        generateScript = true;
        extraCommands = ''
          trap '${pkgs.systemd}/bin/systemctl --user stop --job-mode=replace-irreversibly graphical-session.target graphical-session-pre.target; ${pkgs.systemd}/bin/systemctl --user unset-environment DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE' EXIT
          trap 'exit' TERM INT
          export XDG_CURRENT_DESKTOP=i3
          export XDG_SESSION_DESKTOP=i3
          export XDG_SESSION_TYPE=x11
          systemctl --user import-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
          ${pkgs.xset}/bin/xset s noblank
          ${pkgs.xset}/bin/xset -dpms
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
      xsession.windowManager.i3 = {
        enable = true;
        config = {
          modifier = "Mod4";
          terminal = "${pkgs.ghostty}/bin/ghostty";
          keybindings = lib.mkOptionDefault {
            "Mod4+Shift+l" = "exec ${pkgs.systemd}/bin/loginctl lock-session";
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
