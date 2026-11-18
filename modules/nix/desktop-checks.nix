{ config, ... }:
let
  nixos = config.flake.modules.nixos;
  desktop = config.flake.nixosConfigurations.desktop.config;
in
{
  perSystem = { pkgs, ... }: {
    packages.desktop-access = pkgs.testers.runNixOSTest (
      import ../../checks/desktop-access.nix {
        inherit nixos;
        firewallExtraCommands = desktop.networking.firewall.extraCommands;
      }
    );
    packages.desktop-snapshots = pkgs.testers.runNixOSTest (
      import ../../checks/desktop-snapshots.nix { inherit nixos; }
    );
  };
}
