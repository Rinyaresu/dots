{ config, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.tailscale = pkgs.testers.runNixOSTest (
      import ../../checks/tailscale.nix {
        inherit (config.flake.modules) nixos;
      }
    );
  };
}
