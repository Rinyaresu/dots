{ config, ... }:
let
  home = config.flake.nixosConfigurations.desktop.config.home-manager.users.rinyaresu;
  plugin = home.xdg.configFile."herdr/plugins-src/nvim-file-links".source;
  plannotator = home.xdg.configFile."plannotator-tui/config.toml".source;
  package =
    name: builtins.head (builtins.filter (pkg: (pkg.pname or pkg.name) == name) home.home.packages);
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.herdr-integrations =
        pkgs.runCommand "herdr-integrations-check"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.python3
            ];
          }
          ''
            export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_STATE_HOME="$TMPDIR/state"
            export HERDR_SOCKET_PATH="$TMPDIR/isolated.sock"
            mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
            ${package "herdr"}/bin/herdr plugin link ${plugin} > /dev/null
            ${package "herdr"}/bin/herdr plugin link ${plugin} > /dev/null
            ${package "herdr"}/bin/herdr plugin list --json | jq -e '
              .result.plugins | length == 1 and .[0].plugin_id == "local.nvim-file-links"
              and .[0].enabled and .[0].link_handlers[0].action == "open"
            '
            python ${../../checks/herdr-integrations.py} ${plugin} ${plannotator} \
              ${home.xdg.configFile."herdr/config.toml".source} ${package "herdr-links"}/bin/herdr-links
            touch "$out"
          '';
      checks.work-tools =
        pkgs.runCommand "work-tools-check"
          {
            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.python3
            ];
          }
          ''
            python ${../../checks/work-tools.py} ${package "clean"}/bin/clean
            touch "$out"
          '';
    };
}
