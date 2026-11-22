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
            if not set -q SSH_CONNECTION; and not set -q SSH_TTY; and not set -q TMUX
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

  flake.modules.homeManager.desktop-personal =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      script = name: pkgs.writeShellScriptBin name (builtins.readFile (./_herdr + "/${name}"));
      links = pkgs.writeScriptBin "herdr-links" ''
        #!${lib.getExe pkgs.python3}
        ${builtins.readFile ./_herdr/herdr-links}
      '';
      pluginDir = "${config.xdg.configHome}/herdr/plugins-src/nvim-file-links";
      annotate = pkgs.writeShellScriptBin "herdr-annotate-install" ''
        set -euo pipefail
        plugins="$(${lib.getExe herdr} plugin list --plugin annotate --json)"
        if ${lib.getExe pkgs.jq} -e '.result.plugins | any(.plugin_id == "annotate")' <<< "$plugins" >/dev/null; then
          printf '%s\n' 'Herdr Annotate já está instalado.'
        else
          exec ${lib.getExe herdr} plugin install plannotator/herdr-annotate
        fi
      '';
    in
    {
      key = "${__curPos.file}#homeManager.herdr-desktop";
      home.packages = [
        pkgs.cargo
        pkgs.rustc
        pkgs.python3
        pkgs.xdg-utils
        links
        annotate
      ]
      ++ map script [
        "sessionizer"
        "work"
        "work-herdr"
        "unwork"
        "unwork-herdr"
      ];
      xdg.configFile."herdr/config.toml".text = lib.mkBefore (builtins.readFile ./_herdr/config.toml);
      xdg.configFile."plannotator-tui/config.toml".source = ./_herdr/plannotator-tui.toml;
      xdg.configFile."herdr/plugins-src/nvim-file-links".source = ./_herdr/nvim-file-links;
      home.activation.herdrNvimFileLinks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${lib.getExe' pkgs.coreutils "env"} XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome} \
          ${lib.getExe herdr} plugin link ${lib.escapeShellArg pluginDir}
      '';
    };

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.herdr ];
  };
}
