{ inputs, ... }:
{
  configurations.nixos.desktop.modules.storage = {
    imports = [
      inputs.disko.nixosModules.disko
      ./_disko-layout.nix
    ];
  };
}
