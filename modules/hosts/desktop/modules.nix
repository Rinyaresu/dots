{ config, inputs, ... }:
let
  nixos = config.flake.modules.nixos;
in
{
  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [ nixos.host-desktop ];
  };

  flake.modules.nixos.host-desktop.imports = [
    nixos.nix-settings
    nixos.networking
    nixos.locale
    nixos.sudo
    nixos.rinyaresu
    nixos.tools
    nixos.wireguard
    nixos.zram
    nixos.no-hibernation
    nixos.ssh-agent
    nixos.unfree-desktop
    nixos.graphics
    nixos.fonts
    nixos.polkit
    nixos.files
    nixos.firefox
    nixos.i3
    nixos.bluetooth
    nixos.sound
    nixos.toolchain
    nixos.docker
    nixos.niri
    nixos.limine
    nixos.rinyaresu-ssh
    nixos.pi-bootstrap
    nixos.virtualisation
  ];
}
