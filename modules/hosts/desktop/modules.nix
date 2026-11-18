{ config, ... }:
let
  nixos = config.flake.modules.nixos;
in
{
  configurations.nixos.desktop = {
    homeUser = "rinyaresu";
    modules = {
      inherit (nixos)
        base
        gui
        i3
        niri
        desktop-personal
        tailscale
        home-snapshots
        wireguard
        zram
        no-hibernation
        docker
        limine
        virtualisation
        ;
    };
  };
}
