{ config, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.tailscale = pkgs.testers.runNixOSTest (
      import ../../checks/tailscale.nix {
        ordisModules = builtins.attrValues (
          removeAttrs config.configurations.nixos.ordis.modules [ "maintenance" ]
        );
      }
    );
  };
}
