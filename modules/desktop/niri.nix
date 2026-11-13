{
  flake.modules.nixos.niri =
    { pkgs, ... }:
    {
      programs.niri.enable = true;
      environment.systemPackages = [ pkgs.xwayland-satellite ];
      services.gnome.gnome-keyring.enable = true;
      services.gnome.gcr-ssh-agent.enable = false;
    };

  flake.modules.homeManager.niri =
    { pkgs, ... }:
    let
      niriConfig = pkgs.writeText "niri-config.kdl" ''
        input {
            keyboard {
                xkb {
                    layout "us"
                    variant "intl"
                }
            }
        }

        layout {
            background-color "#faf4ed"
        }

        screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

        binds {
            Mod+Return { spawn "${pkgs.ghostty}/bin/ghostty"; }
            Mod+D { spawn-sh "${pkgs.noctalia}/bin/noctalia msg panel-toggle launcher"; }
            Mod+C { spawn-sh "${pkgs.noctalia}/bin/noctalia msg panel-toggle clipboard"; }
            Super+Alt+L { spawn-sh "${pkgs.noctalia}/bin/noctalia msg session lock"; }
            Mod+Q repeat=false { close-window; }
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
            Mod+Ctrl+1 { move-column-to-workspace 1; }
            Mod+Ctrl+2 { move-column-to-workspace 2; }
            Mod+Ctrl+3 { move-column-to-workspace 3; }
            Mod+Ctrl+4 { move-column-to-workspace 4; }
            Mod+Ctrl+5 { move-column-to-workspace 5; }
            Mod+Ctrl+6 { move-column-to-workspace 6; }
            Mod+Ctrl+7 { move-column-to-workspace 7; }
            Mod+Ctrl+8 { move-column-to-workspace 8; }
            Mod+Ctrl+9 { move-column-to-workspace 9; }
            Mod+R { switch-preset-column-width; }
            Mod+F { maximize-column; }
            Mod+V { toggle-window-floating; }
            Print { screenshot; }
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
        enabled = false

        [theme]
        mode = "light"
        source = "builtin"
        builtin = "Rosé Pine"

        [notification]
        enable_daemon = true

        [idle.behavior.lock]
        timeout = 600
        action = "lock"
        enabled = true

        [lockscreen]
        enabled = true
        lock_before_suspend = true
      '';
    in
    {
      home.packages = [ pkgs.noctalia ];
      xdg.configFile = {
        "niri/config.kdl".source = niriConfig;
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
