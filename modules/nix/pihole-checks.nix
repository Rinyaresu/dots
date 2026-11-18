{ config, ... }:
let
  ordis = config.flake.nixosConfigurations.ordis.config;
in
{
  perSystem = { pkgs, ... }: {
    packages.pihole = import ../../checks/pihole.nix {
      inherit pkgs ordis;
      piholeModule = config.flake.modules.nixos.pihole;
    };
  };
}
