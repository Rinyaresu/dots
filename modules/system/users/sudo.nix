{ config, ... }:
{
  flake.modules.nixos.sudo.key = "${__curPos.file}#nixos.sudo";
  flake.modules.nixos.sudo.security.sudo.wheelNeedsPassword = true;

  flake.modules.nixos.common = {
    imports = [ config.flake.modules.nixos.sudo ];
  };
}
