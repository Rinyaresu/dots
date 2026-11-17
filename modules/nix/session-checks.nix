{
  config,
  inputs,
  lib,
  ...
}:
let
  desktop = config.flake.nixosConfigurations.desktop.config;
  home = desktop.home-manager.users.rinyaresu;
  labHome = config.flake.nixosConfigurations.lab.config.home-manager.users.rinyaresu;
  ordis = config.flake.nixosConfigurations.ordis.config;
  restore = builtins.head home.systemd.user.services.pi-config-restore.Service.ExecStart;
  herdr = builtins.head (
    builtins.filter (package: (package.pname or "") == "herdr") home.home.packages
  );
  agentFixture =
    extra:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        config.flake.modules.nixos.ssh-agent
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "26.05";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
        }
      ]
      ++ extra;
    };
  rejectsAgent =
    extra:
    !(builtins.tryEval (
      builtins.deepSeq (agentFixture extra).config.system.build.toplevel.drvPath true
    )).success;
  results = {
    reject-competing-gcr = rejectsAgent [ { services.gnome.gcr-ssh-agent.enable = true; } ];
    reject-identity-expiration = rejectsAgent [ { programs.ssh.agentTimeout = 60; } ];
    single-native-agent =
      desktop.programs.ssh.startAgent && !desktop.services.gnome.gcr-ssh-agent.enable;
    no-identity-expiration = desktop.programs.ssh.agentTimeout == null;
    graphical-askpass = desktop.programs.ssh.enableAskPassword;
    agent-adds-on-demand = lib.hasInfix "AddKeysToAgent yes" desktop.programs.ssh.extraConfig;
    bootstrap-socket = builtins.elem "SSH_AUTH_SOCK=%t/ssh-agent" home.systemd.user.services.pi-config-restore.Service.Environment;
    bootstrap-graphical-prompt = builtins.elem "SSH_ASKPASS_REQUIRE=force" home.systemd.user.services.pi-config-restore.Service.Environment;
    mise-automatic-hook = home.programs.mise.enableFishIntegration;
    mise-explicit-install =
      !home.programs.mise.globalConfig.settings.auto_install
      && !home.programs.mise.globalConfig.settings.exec_auto_install
      && !home.programs.mise.globalConfig.settings.not_found_auto_install
      && !home.programs.mise.globalConfig.settings.task.run_auto_install;
    mise-explicit-trust = home.programs.mise.globalConfig.settings.trusted_config_paths == [ ];
    direnv-automatic-hook = home.programs.direnv.enable && home.programs.direnv.enableFishIntegration;
    no-competing-mise-direnv = !home.programs.direnv.mise.enable;
    no-herdr-login-daemon = !(home.systemd.user.services ? herdr);
    desktop-tree-layout =
      lib.hasInfix "$agent_tree_branch"
        home.xdg.configFile."herdr/config.toml".text;
    lab-without-tree =
      !(lib.hasInfix "$agent_tree_branch" labHome.xdg.configFile."herdr/config.toml".text);
    ordis-without-home-manager = !(ordis ? home-manager);
    fish-login = desktop.users.users.rinyaresu.shell == desktop.programs.fish.package;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: pass: !pass) results);
in
{
  perSystem =
    { pkgs, ... }:
    let
      init = pkgs.writeText "session-init.fish" home.programs.fish.interactiveShellInit;
      function = pkgs.writeText "session-herdr.fish" ''
        function herdr
          ${home.programs.fish.functions.herdr.body}
        end
      '';
    in
    {
      checks.session-contract =
        assert lib.assertMsg (
          failures == [ ]
        ) "Session contract failures: ${lib.concatStringsSep ", " failures}";
        pkgs.writeText "session-contract.json" (builtins.toJSON results);
      checks.herdr-tree-config =
        pkgs.runCommand "herdr-tree-config-check" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python - ${home.xdg.configFile."herdr/config.toml".source} <<'PY'
            import pathlib, sys, tomllib
            config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
            assert config["onboarding"] is False
            assert config["ui"]["sidebar"]["agents"]["rows"] == [
                ["state_icon", "$agent_tree_branch", "machine", "workspace", "tab"],
                ["agent"],
            ]
            assert config["terminal"]["default_shell"]
            assert config["update"] == {"version_check": False, "manifest_check": False}
            PY
            HERDR_CONFIG_PATH=${home.xdg.configFile."herdr/config.toml".source} ${herdr}/bin/herdr config check
            touch "$out"
          '';
      checks.shell-session =
        pkgs.runCommand "shell-session-check" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python ${../../checks/shell-session.py} ${pkgs.fish}/bin/fish ${init} ${function} ${herdr}/bin/herdr
            touch "$out"
          '';
      checks.shell-providers =
        pkgs.runCommand "shell-providers-check" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python ${../../checks/shell-providers.py} ${pkgs.fish}/bin/fish ${init} ${function} \
              ${herdr}/bin/herdr ${home.programs.mise.package}/bin/mise \
              ${home.programs.direnv.package}/bin/direnv ${home.xdg.configFile."mise/config.toml".source}
            touch "$out"
          '';
      checks.bootstrap-session =
        pkgs.runCommand "bootstrap-session-check" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python ${../../checks/bootstrap-session.py} ${restore} \
              ssh-add=${pkgs.openssh} git=${pkgs.git} systemctl=${pkgs.systemd} sleep=${pkgs.coreutils}
            touch "$out"
          '';
      checks.ssh-session = import ../../checks/ssh-session.nix {
        nixos = config.flake.modules.nixos;
        inherit pkgs;
      };
      checks.ssh-agent = pkgs.runCommand "ssh-agent-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python ${../../checks/ssh-agent.py} ${pkgs.openssh}
        touch "$out"
      '';
    };
}
