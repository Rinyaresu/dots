{ config, inputs, ... }:
let
  nixos = config.flake.modules.nixos;
in
{
  configurations.nixos.lab = {
    homeUser = "rinyaresu";
    modules = {
      inherit (nixos)
        base
        gui
        i3
        niri
        wireguard
        zram
        no-hibernation
        docker
        sops
        virtualisation
        ;
      qemu = "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix";
    };
  };
}
