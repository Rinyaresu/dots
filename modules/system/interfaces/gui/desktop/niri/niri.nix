{ config, ... }:
{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      key = "${__curPos.file}#nixos.niri";
      programs.niri.enable = true;
      environment.systemPackages = [ pkgs.xwayland-satellite ];
      services.gnome.gnome-keyring.enable = true;
      services.gnome.gcr-ssh-agent.enable = false;
    };

  flake.modules.homeManager.niri =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      simpleBlue = pkgs.nixos-artwork.wallpapers.simple-blue;
      pactl = lib.getExe' pkgs.pulseaudio "pactl";
      brightnessctl = lib.getExe pkgs.brightnessctl;
      sattyConfig = pkgs.writeText "satty-capture.toml" ''
        [general]
        early-exit = true
        copy-command = "${pkgs.coreutils}/bin/true"
        actions-on-enter = ["save-to-file"]
        actions-on-right-click = ["save-to-file"]
        actions-on-escape = ["exit"]
        disable-notifications = true
      '';
      capture = pkgs.writeShellScriptBin "niri-screenshot" ''
        set -euo pipefail
        umask 077
        work=$(${pkgs.coreutils}/bin/mktemp -d "''${XDG_RUNTIME_DIR:?}/niri-screenshot.XXXXXX")
        trap '${pkgs.coreutils}/bin/rm -rf -- "$work"' EXIT
        geometry=$(${pkgs.slurp}/bin/slurp) || exit 0
        [[ -n "$geometry" ]] || exit 0
        ${pkgs.grim}/bin/grim -g "$geometry" "$work/capture.png"
        ${pkgs.satty}/bin/satty --config ${sattyConfig} \
          --filename "$work/capture.png" --output-filename "$work/edited.png"
        [[ -s "$work/edited.png" ]] || exit 0
        directory="$HOME/Pictures/Screenshots"
        ${pkgs.coreutils}/bin/mkdir -p "$directory"
        destination=$(${pkgs.coreutils}/bin/mktemp "$directory/Screenshot-$(${pkgs.coreutils}/bin/date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")
        ${pkgs.coreutils}/bin/cat "$work/edited.png" > "$destination"
        ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$destination"
      '';
      niriConfig = ''
        input {
            keyboard {
                xkb {
                    layout "us,br"
                    variant "intl,"
                }
            }
        }

        layout {
            background-color "#faf4ed"
            focus-ring {
                active-color "#d7827e"
            }
        }

        screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

        binds {
            Mod+Return { spawn "${pkgs.ghostty}/bin/ghostty"; }
            Mod+D { spawn-sh "${pkgs.noctalia}/bin/noctalia msg panel-toggle launcher"; }
            Mod+C { spawn-sh "${pkgs.noctalia}/bin/noctalia msg panel-toggle clipboard"; }
            Super+Alt+L { spawn-sh "${pkgs.noctalia}/bin/noctalia msg session lock"; }
            Mod+Shift+Q repeat=false { close-window; }
            Mod+Alt+B hotkey-overlay-title="Brazilian keyboard" { switch-layout "1"; }
            Mod+Alt+U hotkey-overlay-title="US international keyboard" { switch-layout "0"; }
            Mod+Shift+Slash { show-hotkey-overlay; }
            Mod+O repeat=false { toggle-overview; }
            Mod+Left { focus-column-left; }
            Mod+Right { focus-column-right; }
            Mod+Up { focus-window-up; }
            Mod+Down { focus-window-down; }
            Mod+H { focus-column-left; }
            Mod+J { focus-window-down; }
            Mod+K { focus-window-up; }
            Mod+L { focus-column-right; }
            Mod+1 { focus-workspace 1; }
            Mod+2 { focus-workspace 2; }
            Mod+3 { focus-workspace 3; }
            Mod+4 { focus-workspace 4; }
            Mod+5 { focus-workspace 5; }
            Mod+6 { focus-workspace 6; }
            Mod+7 { focus-workspace 7; }
            Mod+8 { focus-workspace 8; }
            Mod+9 { focus-workspace 9; }
            Mod+0 { focus-workspace 10; }
            Mod+Shift+1 { move-column-to-workspace 1; }
            Mod+Shift+2 { move-column-to-workspace 2; }
            Mod+Shift+3 { move-column-to-workspace 3; }
            Mod+Shift+4 { move-column-to-workspace 4; }
            Mod+Shift+5 { move-column-to-workspace 5; }
            Mod+Shift+6 { move-column-to-workspace 6; }
            Mod+Shift+7 { move-column-to-workspace 7; }
            Mod+Shift+8 { move-column-to-workspace 8; }
            Mod+Shift+9 { move-column-to-workspace 9; }
            Mod+Shift+0 { move-column-to-workspace 10; }
            Mod+Shift+H { move-column-left; }
            Mod+Shift+J { move-window-down; }
            Mod+Shift+K { move-window-up; }
            Mod+Shift+L { move-column-right; }
            Mod+R { switch-preset-column-width; }
            Mod+Ctrl+H { set-column-width "-5%"; }
            Mod+Ctrl+L { set-column-width "+5%"; }
            Mod+Ctrl+J { set-window-height "+5%"; }
            Mod+Ctrl+K { set-window-height "-5%"; }
            Mod+W { toggle-column-tabbed-display; }
            Mod+Comma { consume-window-into-column; }
            Mod+Period { expel-window-from-column; }
            Mod+F { fullscreen-window; }
            Mod+Shift+F { maximize-column; }
            Mod+Alt+F { toggle-windowed-fullscreen; }
            Mod+Shift+Space { toggle-window-floating; }
            XF86AudioRaiseVolume allow-when-locked=true { spawn "${pactl}" "set-sink-volume" "@DEFAULT_SINK@" "+10%"; }
            XF86AudioLowerVolume allow-when-locked=true { spawn "${pactl}" "set-sink-volume" "@DEFAULT_SINK@" "-10%"; }
            XF86AudioMute allow-when-locked=true repeat=false { spawn "${pactl}" "set-sink-mute" "@DEFAULT_SINK@" "toggle"; }
            XF86AudioMicMute allow-when-locked=true repeat=false { spawn "${pactl}" "set-source-mute" "@DEFAULT_SOURCE@" "toggle"; }
            XF86MonBrightnessUp allow-when-locked=true { spawn "${brightnessctl}" "set" "+5%"; }
            XF86MonBrightnessDown allow-when-locked=true { spawn "${brightnessctl}" "set" "5%-"; }
            Print hotkey-overlay-title="Capture region, annotate in Satty, Enter saves and copies" { spawn "${capture}/bin/niri-screenshot"; }
            Mod+Shift+Delete hotkey-overlay-title="Clear unpinned clipboard history" { spawn "${pkgs.noctalia}/bin/noctalia" "msg" "clipboard-clear"; }
            Ctrl+Print { screenshot-screen; }
            Alt+Print { screenshot-window; }
            Mod+Shift+E { quit; }
        }
      '';
      noctaliaConfig = pkgs.writeText "noctalia-config.toml" ''
        [storage]
        key_source = "secret-service"

        [shell]
        setup_wizard_enabled = false
        telemetry_enabled = false
        offline_mode = true
        polkit_agent = false
        clipboard_enabled = true
        clipboard_history_max_entries = 100
        clipboard_keep_from_closed_apps = true
        clipboard_auto_paste = "auto"

        [plugins]
        source = []
        enabled = []
        auto_update = "none"

        [shell.screenshot]
        save_to_file = true
        copy_to_clipboard = true
        pipe_to_command = false
        show_cursor = false

        [wallpaper]
        enabled = true
        directory = "${builtins.dirOf simpleBlue.gnomeFilePath}"

        [wallpaper.default]
        path = "${simpleBlue.gnomeFilePath}"

        [wallpaper.automation]
        enabled = false

        [theme]
        mode = "light"
        source = "builtin"
        builtin = "Rosé Pine"

        [notification]
        enable_daemon = true
        layer = "top"

        [location]
        auto_locate = false
        custom_schedule = true
        sunrise = "06:45"
        sunset = "18:00"

        [nightlight]
        enabled = true
        force = false
        temperature_day = 5900
        temperature_night = 2600

        [idle]
        pre_action_fade_seconds = 0

        [idle.behavior.lock]
        timeout = 600
        action = "lock"
        enabled = true

        [idle.behavior.screen-off]
        timeout = 900
        action = "screen_off"
        enabled = true

        [idle.behavior.suspend]
        enabled = false

        [lockscreen]
        enabled = true
        lock_before_suspend = true
        blurred_desktop = false
        allow_empty_password = false
        fingerprint = false
      '';
    in
    {
      key = "${__curPos.file}#homeManager.niri";
      imports = [ config.flake.modules.homeManager.ghostty ];
      assertions = [
        {
          assertion = osConfig.programs.niri.enable;
          message = "The Niri home configuration requires Niri on this host.";
        }
        {
          assertion = osConfig.services.gnome.gnome-keyring.enable;
          message = "The Noctalia encrypted-history preset requires GNOME Keyring Secret Service.";
        }
      ];
      home.packages = [
        pkgs.noctalia
        pkgs.satty
        capture
      ];
      dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-light";
      xdg.configFile = {
        "niri/config.kdl".text = niriConfig;
        "noctalia/config.toml".source = noctaliaConfig;
      };
      systemd.user.services.noctalia = {
        Unit = {
          Description = "Noctalia Wayland desktop shell";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
        };
        Service = {
          ExecStart = "${pkgs.noctalia}/bin/noctalia";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
