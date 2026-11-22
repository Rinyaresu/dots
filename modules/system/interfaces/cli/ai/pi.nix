{ config, inputs, ... }:
{
  flake.modules.homeManager.pi =
    { lib, pkgs, ... }:
    let
      pi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        nodejs_22 = pkgs.nodejs_24;
        importNpmLock = pkgs.importNpmLock // {
          importNpmLock =
            args:
            pkgs.importNpmLock (
              args
              // pkgs.lib.optionalAttrs (args ? packageSourceOverrides) {
                packageSourceOverrides = args.packageSourceOverrides // {
                  "node_modules/@earendil-works/pi-schema" = pkgs.fetchurl {
                    url = "https://registry.npmjs.org/@earendil-works/pi-schema/-/pi-schema-1.5.0.tgz";
                    hash = "sha512-RW0MbT2tR65OY6xMsgB/yVBb7m/RTNwA+9hurSN1vVXfHZRVmVnXbruBPrx/PzbrQnW5yLVlMRWxErGDQtF1Hg==";
                  };
                };
              }
            );
        };
      };
      ai = pkgs.writeShellScriptBin "ai" ''
        set -euo pipefail
        export CODEX_ROTATOR_ENABLE_ADMISSION_CONTROL=true
        export CODEX_ROTATOR_ENABLE_HEADROOM_SCHEDULER=true
        export CODEX_ROTATOR_ENABLE_PROVIDER_PROTECTION=true
        export CODEX_ROTATOR_MAX_INFLIGHT_PER_ACCOUNT=2
        export CODEX_ROTATOR_MAX_INFLIGHT_GLOBAL=6
        export PI_FLEET_PI_COMMAND="$(${lib.getExe' pkgs.coreutils "readlink"} -f -- "''${BASH_SOURCE[0]}")"
        exec ${lib.getExe pi} "$@"
      '';
    in
    {
      key = "${__curPos.file}#homeManager.pi";
      home.packages = [
        pi
        ai
      ];
      home.sessionVariables.PI_NODE_BIN = "${pkgs.nodejs_24}/bin/node";
    };

  flake.modules.homeManager.desktop-personal = { pkgs, ... }: {
    home.packages = [ pkgs.nodejs_24 ];
    home.sessionPath = [ "$HOME/.pi/agent/bin" ];
  };

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.pi ];
  };
}
