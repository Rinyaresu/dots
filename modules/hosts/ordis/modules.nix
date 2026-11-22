{ config, ... }:
{
  configurations.nixos.ordis.modules = {
    inherit (config.flake.modules.nixos) common tailscale zram;
  };
}
