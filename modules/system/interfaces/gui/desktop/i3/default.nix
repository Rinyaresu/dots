{ config, ... }:

let
  inherit (config.flake.modules.homeManager) ghostty;
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
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      dawn = {
        base = "#faf4ed";
        surface = "#fffaf3";
        overlay = "#f2e9e1";
        muted = "#9893a5";
        subtle = "#797593";
        text = "#575279";
        love = "#b4637a";
        rose = "#d7827e";
        iris = "#907aa9";
        highlightMed = "#dfdad9";
      };
      font = "Iosevka Nerd Font";
      fontSize = "15";
      fonts = {
        names = [ font ];
        size = fontSize;
      };
      windowColors = border: background: text: indicator: childBorder: {
        inherit
          border
          background
          text
          indicator
          childBorder
          ;
      };
      workspaceColors = background: text: {
        border = background;
        inherit background text;
      };
      refreshStatus = "${lib.getExe' pkgs.procps "pkill"} -USR1 -x i3status";
      audio =
        args: "exec --no-startup-id ${lib.getExe' pkgs.pulseaudio "pactl"} ${args} && ${refreshStatus}";
      brightness = step: "exec --no-startup-id ${lib.getExe pkgs.brightnessctl} set ${step}";
      i3bin = "${pkgs.i3}/bin";
    in
    {
      key = "${__curPos.file}#homeManager.i3";
      imports = [ ghostty ];
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
          terminal = lib.getExe config.programs.ghostty.package;
          menu = ''${i3bin}/i3-dmenu-desktop --dmenu="${lib.getExe pkgs.dmenu} -i -fn '${font}-${fontSize}' -nb '${dawn.base}' -nf '${dawn.text}' -sb '${dawn.rose}' -sf '${dawn.base}'"'';
          inherit fonts;
          focus.followMouse = false;
          window = {
            titlebar = false;
            border = 3;
          };
          gaps = {
            inner = 8;
            outer = 4;
          };
          colors = with dawn; {
            background = base;
            focused = windowColors rose rose base rose rose;
            focusedInactive = windowColors overlay surface subtle subtle surface;
            unfocused = windowColors overlay surface muted overlay overlay;
            urgent = windowColors love base text love love;
            placeholder = windowColors base base text overlay overlay;
          };
          bars = [
            {
              inherit fonts;
              command = "${i3bin}/i3bar";
              statusCommand = "${lib.getExe pkgs.i3status}";
              trayOutput = "primary";
              colors = with dawn; {
                background = surface;
                statusline = text;
                separator = highlightMed;
                focusedWorkspace = workspaceColors rose base;
                activeWorkspace = workspaceColors overlay text;
                inactiveWorkspace = workspaceColors surface muted;
                urgentWorkspace = workspaceColors love base;
                bindingMode = workspaceColors iris base;
              };
            }
          ];
          keybindings = lib.mkOptionDefault {
            "Mod4+Mod1+l" = "exec ${pkgs.systemd}/bin/loginctl lock-session";
            "Mod4+Mod1+b" = "exec ${pkgs.setxkbmap}/bin/setxkbmap -layout br";
            "Mod4+Mod1+u" = "exec ${pkgs.setxkbmap}/bin/setxkbmap -layout us -variant intl";
            "Mod4+Shift+t" = "exec ${lib.getExe pkgs.dbeaver-bin}";
            "Mod4+h" = "focus left";
            "Mod4+j" = "focus down";
            "Mod4+k" = "focus up";
            "Mod4+l" = "focus right";
            "Mod4+Shift+h" = "move left";
            "Mod4+Shift+j" = "move down";
            "Mod4+Shift+k" = "move up";
            "Mod4+Shift+l" = "move right";
            "Mod4+period" = "split h";
            "Mod4+comma" = "split v";
            "Mod4+Shift+e" =
              "exec ${i3bin}/i3-nagbar -t warning -m 'Do you want to exit i3?' -B 'Yes, exit i3' '${i3bin}/i3-msg exit'";
            XF86AudioRaiseVolume = audio "set-sink-volume @DEFAULT_SINK@ +10%";
            XF86AudioLowerVolume = audio "set-sink-volume @DEFAULT_SINK@ -10%";
            XF86AudioMute = audio "set-sink-mute @DEFAULT_SINK@ toggle";
            XF86AudioMicMute = audio "set-source-mute @DEFAULT_SOURCE@ toggle";
            XF86MonBrightnessUp = brightness "+5%";
            XF86MonBrightnessDown = brightness "5%-";
          };
          modes.resize = {
            j = "resize shrink width 5 px or 5 ppt";
            k = "resize grow height 5 px or 5 ppt";
            l = "resize shrink height 5 px or 5 ppt";
            semicolon = "resize grow width 5 px or 5 ppt";
            Left = "resize shrink width 5 px or 5 ppt";
            Down = "resize grow height 5 px or 5 ppt";
            Up = "resize shrink height 5 px or 5 ppt";
            Right = "resize grow width 5 px or 5 ppt";
            Return = "mode default";
            Escape = "mode default";
            "Mod4+r" = "mode default";
          };
        };
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
