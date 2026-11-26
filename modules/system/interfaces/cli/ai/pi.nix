{ config, inputs, ... }:
{
  flake.modules.homeManager.pi =
    { lib, pkgs, ... }:
    let
      upstreamPi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default;
      pi = upstreamPi.override { nodejs_22 = pkgs.nodejs_24; };
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
