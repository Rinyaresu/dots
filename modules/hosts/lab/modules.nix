{ config, inputs, ... }:
{
  configurations.nixos.lab.modules = {
    inherit (config.flake.modules.nixos)
      base
      gui
      i3
      niri
      bluetooth
      sound
      docker
      virtualisation
      development
      secrets
      ;
    qemu-vm = "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix";
  };
}
