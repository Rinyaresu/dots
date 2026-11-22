{
  flake.modules.homeManager.i3 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      separator = "<span foreground='#cecacd'>|</span>";
      statusModule = position: settings: {
        inherit position;
        settings = {
          separator = false;
          separator_block_width = 10;
        }
        // settings;
      };
      copyqClear = pkgs.writeShellScript "copyq-clear-clipboard" ''
        exec ${pkgs.copyq}/bin/copyq eval 'tab("&clipboard"); while (size()) remove(0);'
      '';
      copyqSeed = pkgs.writeShellScript "copyq-seed-config" ''
        set -eu
        umask 077
        config_dir=${config.xdg.configHome}/copyq
        config_file="$config_dir/copyq.conf"
        if [ ! -e "$config_file" ]; then
          ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
          ${pkgs.coreutils}/bin/cat > "$config_file" <<'EOF'
        [Options]
        maxitems=100
        [Plugins/itemimage]
        enabled=false
        [Plugins/itemtext]
        use_rich_text=false
        [Command]
        Name=Store plain text only
        IsScript=true
        Command="global.clipboardFormatsToSave = function() { return ['text/plain'] }"
        EOF
        fi
      '';
    in
    {
      key = "${__curPos.file}#homeManager.i3";
      programs.i3status = {
        enable = true;
        enableDefault = false;
        general = {
          output_format = "i3bar";
          markup = "pango";
          colors = true;
          interval = 5;
          color_good = "#286983";
          color_degraded = "#ea9d34";
          color_bad = "#b4637a";
        };
        modules = {
          "wireless _first_" = statusModule 1 {
            format_up = "WIFI %essid";
            format_down = "";
          };
          "ethernet _first_" = statusModule 2 {
            format_up = "${separator} LAN %ip";
            format_down = "";
          };
          "path_exists WG" = statusModule 3 {
            path = "/proc/sys/net/ipv4/conf/wg0";
            format = "${separator} WG up";
            format_down = "";
          };
          "battery all" = statusModule 4 {
            format = "${separator} BAT %percentage %remaining";
            format_down = "";
            low_threshold = 10;
            threshold_type = "percentage";
          };
          "volume master" = statusModule 5 {
            format = "${separator} VOL %volume";
            format_muted = "${separator} VOL muted";
            device = "pulse";
          };
          memory = statusModule 6 {
            format = "${separator} MEM %used";
            threshold_degraded = "80%";
            format_degraded = "${separator} MEM %used";
          };
          "tztime local" = statusModule 7 {
            format = "${separator} %Y-%m-%d %H:%M:%S";
          };
        };
      };

      services.dunst.enable = true;
      services.redshift = {
        enable = true;
        temperature = {
          day = 5900;
          night = 2600;
        };
        dawnTime = "06:00-07:30";
        duskTime = "17:00-19:00";
        settings.redshift = {
          adjustment-method = "randr";
          fade = 1;
        };
      };
      systemd.user.services.redshift.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";

      services.copyq = {
        enable = true;
        forceXWayland = false;
        systemdTarget = "graphical-session.target";
      };
      systemd.user.services.copyq = {
        Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";
        Service.ExecStartPre = lib.mkBefore [ copyqSeed ];
      };
      systemd.user.services.dunst.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";

      services.flameshot = {
        enable = true;
        settings.General = {
          disabledTrayIcon = true;
          showStartupLaunchMessage = false;
          saveAfterCopy = false;
          copyPathAfterSave = false;
          uploadWithoutConfirmation = false;
          startupLaunch = false;
          buttons = "@Variant(\\0\\0\\0\\x7f\\0\\0\\0\\vQList<int>\\0\\0\\0\\0\\x15\\0\\0\\0\\0\\0\\0\\0\\x1\\0\\0\\0\\x2\\0\\0\\0\\x3\\0\\0\\0\\x4\\0\\0\\0\\x5\\0\\0\\0\\x6\\0\\0\\0\\x8\\0\\0\\0\\x9\\0\\0\\0\\xa\\0\\0\\0\\xb\\0\\0\\0\\xc\\0\\0\\0\\xe\\0\\0\\0\\xf\\0\\0\\0\\x10\\0\\0\\0\\x11\\0\\0\\0\\x12\\0\\0\\0\\x13\\0\\0\\0\\x14\\0\\0\\0\\x15\\0\\0\\0\\x16)";
        };
      };

      systemd.user.services.flameshot = {
        Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";
        Service.Environment = [ "QT_QPA_PLATFORM=xcb" ];
      };

      xsession.windowManager.i3.config.keybindings = lib.mkOptionDefault {
        Print = "exec --no-startup-id ${pkgs.coreutils}/bin/env QT_QPA_PLATFORM=xcb ${pkgs.flameshot}/bin/flameshot gui";
        "Mod4+c" = "exec ${pkgs.copyq}/bin/copyq show";
        "Mod4+Shift+Delete" = "exec ${copyqClear}";
      };
    };
}
