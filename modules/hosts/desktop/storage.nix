{ inputs, ... }:
{
  configurations.nixos.desktop.modules.storage = {
    imports = [
      inputs.disko.nixosModules.disko
      (import ./_disko-layout.nix (import ./_disko-inventory.nix))
    ];
  };
}
