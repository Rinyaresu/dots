{ config, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.tailscale = pkgs.testers.runNixOSTest (
      import ../../checks/tailscale.nix {
        ordisModules = builtins.attrValues config.configurations.nixos.ordis.modules;
      }
    );
  };
}
