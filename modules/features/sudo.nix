{
  flake.modules.nixos.sudo.key = "${__curPos.file}#nixos.sudo";
  flake.modules.nixos.sudo.security.sudo.wheelNeedsPassword = true;
}
