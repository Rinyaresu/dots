{
  config,
  inputs,
  lib,
  ...
}:
let
  makeFixture =
    extraModules:
    import ../../checks/graphical.nix {
      inherit inputs extraModules;
      nixos = config.flake.modules.nixos;
      home = config.flake.modules.homeManager;
    };
  fixture = makeFixture [ ];
  rejects =
    extra:
    !(builtins.tryEval (builtins.deepSeq (makeFixture extra).config.system.build.toplevel.drvPath true))
    .success;
  system = fixture.config;
  systemPkgs = fixture.pkgs;
  alice = system.home-manager.users.alice;
  services = alice.systemd.user.services;
  capture = lib.findFirst (
    package: (package.name or "") == "niri-screenshot"
  ) null alice.home.packages;
  sessionBound = name: builtins.elem "graphical-session.target" services.${name}.Unit.PartOf;
  i3Only = name: services.${name}.Unit.ConditionEnvironment == "XDG_CURRENT_DESKTOP=i3";
  results = {
    fixture-evaluates = builtins.isString system.system.build.toplevel.drvPath;
    reject-niri-without-system = rejects [ { programs.niri.enable = lib.mkForce false; } ];
    reject-i3-without-system = rejects [
      { services.xserver.windowManager.i3.enable = lib.mkForce false; }
    ];
    reject-without-secret-service = rejects [
      { services.gnome.gnome-keyring.enable = lib.mkForce false; }
    ];
    console-login =
      system.services.xserver.displayManager.startx.enable
      && system.services.xserver.displayManager.startx.generateScript
      && !system.services.displayManager.gdm.enable;
    secret-service-console-pam =
      system.services.gnome.gnome-keyring.enable
      && system.security.pam.services.login.enableGnomeKeyring
      && !system.services.gnome.gcr-ssh-agent.enable;
    wayland-sharing-portals =
      system.xdg.portal.enable
      && builtins.elem "gnome" (lib.splitString ";" system.xdg.portal.config.niri.default)
      && builtins.elem system.programs.niri.package system.environment.systemPackages
      && system.services.pipewire.enable;
    independent-session-services =
      services.noctalia.Unit.ConditionEnvironment == "XDG_CURRENT_DESKTOP=niri"
      && builtins.all i3Only [
        "copyq"
        "dunst"
        "flameshot"
        "redshift"
        "xss-lock"
      ];
    services-stop-with-session = builtins.all sessionBound [
      "noctalia"
      "copyq"
      "dunst"
      "flameshot"
      "redshift"
      "xss-lock"
      "discord"
    ];
    discord-once-per-session =
      services.discord.Install.WantedBy == [ "graphical-session.target" ]
      && services.discord.Service.ExecStart == [ "${systemPkgs.discord}/bin/Discord" ]
      && !(services.discord.Service ? Restart);
    terminal-font =
      alice.programs.ghostty.settings.font-family == [ "IosevkaTerm Nerd Font" ]
      && alice.programs.ghostty.settings.font-size == [ 15 ]
      && builtins.elem systemPkgs.nerd-fonts.iosevka-term system.fonts.packages;
    terminal-legibility =
      alice.programs.ghostty.settings.adjust-cell-height == [ 1 ]
      && alice.programs.ghostty.settings.cursor-style == [ "block" ]
      && alice.programs.ghostty.settings.cursor-style-blink == [ false ]
      && alice.programs.ghostty.settings.window-padding-x == [ 4 ]
      && alice.programs.ghostty.settings.window-padding-y == [ 4 ];
    i3-night-light =
      alice.services.redshift.enable
      && alice.services.redshift.temperature.day == 5900
      && alice.services.redshift.temperature.night == 2600
      && alice.services.redshift.dawnTime == "06:00-07:30"
      && alice.services.redshift.duskTime == "17:00-19:00";
    i3-locking =
      alice.services.screen-locker.inactiveInterval == 10
      && !alice.services.screen-locker.xautolock.enable
      && builtins.elem "--transfer-sleep-lock" alice.services.screen-locker.xss-lock.extraOptions;
    capture-installed = capture != null;
    no-physical-output-in-shared-capability =
      !(lib.hasInfix "output \"" alice.xdg.configFile."niri/config.kdl".text);
  };
  failures = builtins.attrNames (lib.filterAttrs (_: pass: !pass) results);
in
{
  perSystem = { pkgs, ... }: {
    checks.graphical-policy =
      assert lib.assertMsg (
        failures == [ ]
      ) "Graphical policy checks failed: ${lib.concatStringsSep ", " failures}";
      pkgs.writeText "graphical-policy.json" (builtins.toJSON results);
    checks.graphical-behavior =
      pkgs.runCommand "graphical-behavior" { nativeBuildInputs = [ pkgs.python3 ]; }
        ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          python ${../../checks/graphical-behavior.py} \
            --capture ${capture}/bin/niri-screenshot \
            --lock ${alice.services.screen-locker.lockCmd} \
            --session ${pkgs.writeText "startx-extra" system.services.xserver.displayManager.startx.extraCommands} \
            --noctalia ${alice.xdg.configFile."noctalia/config.toml".source} \
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
      export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_STATE_HOME="$TMPDIR/state"
      mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
      ${pkgs.niri}/bin/niri validate --config ${alice.xdg.configFile."niri/config.kdl".source}
      ${pkgs.niri}/bin/niri validate --config ${
        config.flake.nixosConfigurations.desktop.config.home-manager.users.rinyaresu.xdg.configFile."niri/config.kdl".source
      }
      ${pkgs.niri}/bin/niri validate --config ${
        config.flake.nixosConfigurations.lab.config.home-manager.users.rinyaresu.xdg.configFile."niri/config.kdl".source
      }
      ${pkgs.ghostty}/bin/ghostty +validate-config --config-file=${
        alice.xdg.configFile."ghostty/config".source
      }
      ${pkgs.noctalia}/bin/noctalia config validate ${
        alice.xdg.configFile."noctalia/config.toml".source
      } > validation.log 2>&1
      cat validation.log
      if grep -q WARN validation.log; then exit 1; fi
      touch "$out"
    '';
  };
}
