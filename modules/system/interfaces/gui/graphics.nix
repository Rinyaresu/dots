{ config, ... }:
{
  flake.modules.nixos.graphics.key = "${__curPos.file}#nixos.graphics";
  flake.modules.nixos.graphics.hardware.graphics.enable = true;

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.graphics ];
  };
}
