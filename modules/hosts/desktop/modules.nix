{ config, ... }:
{
  configurations.nixos.desktop.modules = {
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
      limine
      personal-secrets
      pi-bootstrap
      ;
  };
}
