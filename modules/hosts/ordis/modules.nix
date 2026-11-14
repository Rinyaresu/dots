{ config, inputs, ... }:
{
  flake.nixosConfigurations.ordis = inputs.nixpkgs.lib.nixosSystem {
    modules = [ config.flake.modules.nixos.host-ordis ];
  };
}
