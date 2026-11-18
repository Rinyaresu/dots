{ config, ... }:
{
  flake.modules.nixos.networking = {
    key = "${__curPos.file}#nixos.networking";
    networking.firewall.enable = true;
    networking.networkmanager.enable = true;
  };

  flake.modules.nixos.common = {
    imports = [ config.flake.modules.nixos.networking ];
  };
}
