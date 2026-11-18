{ config, inputs, ... }:
let
  fish = config.flake.modules.homeManager.fish;
in
{
  flake.modules.homeManager.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
    in
    {
      key = "${__curPos.file}#homeManager.herdr";
      imports = [ fish ];
      home.packages = [ herdr ];
      programs.fish.functions.herdr.body = ''
        ${pkgs.fish}/bin/fish --no-config -c '
          cd "$HOME"; or exit 1
          ${lib.optionalString config.programs.direnv.enable ''
            set -l clean_direnv (${lib.getExe config.programs.direnv.package} export fish)
            or exit 1
            printf "%s\\n" $clean_direnv | source
            or exit 1
          ''}
          ${lib.optionalString config.programs.mise.enable ''
            set -l clean_mise (${lib.getExe config.programs.mise.package} hook-env --shell fish)
            or exit 1
            printf "%s\\n" $clean_mise | source
            or exit 1
          ''}
          cd "$argv[1]"; or exit 1
          set -e argv[1]
          exec ${herdr}/bin/herdr $argv
        ' -- "$PWD" $argv
      '';
      programs.fish.interactiveShellInit = lib.mkBefore ''
        if status is-interactive; and isatty stdin
          if not set -q HERDR_ENV; and not set -q HERDR_PANE_ID; and not set -q HERDR_NO_AUTO
            if not set -q SSH_CONNECTION; and not set -q SSH_TTY
              if set -q WAYLAND_DISPLAY; or set -q DISPLAY
                herdr
              end
            end
          end
        end
      '';
      xdg.configFile."herdr/config.toml".text = ''

        [terminal]
        default_shell = "${pkgs.fish}/bin/fish"

        [update]
        version_check = false
        manifest_check = false
      '';
    };

  flake.modules.homeManager.desktop-personal = { lib, pkgs, ... }: {
    key = "${__curPos.file}#homeManager.herdr-tree";
    imports = [ config.flake.modules.homeManager.herdr ];
    home.packages = [
      pkgs.cargo
      pkgs.rustc
    ];
    xdg.configFile."herdr/config.toml".text = lib.mkBefore ''
      onboarding = false

      [ui.sidebar.agents]
      rows = [
        ["state_icon", "$agent_tree_branch", "machine", "workspace", "tab"],
        ["agent"],
      ]
    '';
  };

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.herdr ];
  };
}
