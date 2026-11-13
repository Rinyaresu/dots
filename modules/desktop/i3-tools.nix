{
  flake.modules.homeManager.i3 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      copyqClear = pkgs.writeShellScript "copyq-clear-clipboard" ''
        exec ${pkgs.copyq}/bin/copyq eval 'tab("&clipboard"); while (size()) remove(0);'
      '';
      copyqSeed = pkgs.writeShellScript "copyq-seed-config" ''
        set -eu
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
      services.dunst = {
        enable = true;
      };

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

      systemd.user.services.flameshot.Unit.ConditionEnvironment = "XDG_CURRENT_DESKTOP=i3";

      xsession.windowManager.i3.config.keybindings = lib.mkOptionDefault {
        "Print" = "exec ${pkgs.flameshot}/bin/flameshot gui";
        "Mod4+c" = "exec ${pkgs.copyq}/bin/copyq show";
        "Mod4+Shift+Delete" = "exec ${copyqClear}";
      };
    };
}
