{
  config,
  lib,
  ...
}:
let
  desktop = config.flake.nixosConfigurations.desktop.config;
  home = desktop.home-manager.users.rinyaresu;
  labHome = config.flake.nixosConfigurations.lab.config.home-manager.users.rinyaresu;
  restore = builtins.head home.systemd.user.services.pi-config-restore.Service.ExecStart;
  herdr = builtins.head (
    builtins.filter (package: (package.pname or "") == "herdr") home.home.packages
  );

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
      checks.herdr-tree-config =
        assert lib.assertMsg (
          !(lib.hasInfix "$agent_tree_branch" labHome.xdg.configFile."herdr/config.toml".text)
        ) "Lab must not include the personal Herdr TreeView.";
        pkgs.runCommand "herdr-tree-config-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
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
      packages.ssh-session = import ../../checks/ssh-session.nix {
        nixos = config.flake.modules.nixos;
        inherit pkgs;
      };
      checks.ssh-agent = pkgs.runCommand "ssh-agent-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python ${../../checks/ssh-agent.py} ${pkgs.openssh}
        touch "$out"
      '';
    };
}
