{ config, ... }:
{
  flake.modules.nixos.bluetooth.key = "${__curPos.file}#nixos.bluetooth";
  flake.modules.nixos.bluetooth.hardware.bluetooth.enable = true;

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.bluetooth ];
  };
}
