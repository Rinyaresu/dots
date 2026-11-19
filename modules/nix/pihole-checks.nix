{ config, ... }:
let
  ordis = config.flake.nixosConfigurations.ordis.config;
in
{
  perSystem = { pkgs, ... }: {
    packages = let
      test = experiment: import ../../checks/pihole.nix {
        inherit pkgs ordis experiment;
        piholeModule = config.flake.modules.nixos.pihole;
      };
    in {
      pihole = test "off";
      pihole-control = test "control";
      pihole-observe = test "observe";
    };
  };
}
