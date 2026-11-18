{
  flake.modules.nixos.common.key = "${__curPos.file}#nixos.sudo";
  flake.modules.nixos.common.security.sudo.wheelNeedsPassword = true;
}
