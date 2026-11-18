{
  flake.modules.nixos.zram.key = "${__curPos.file}#nixos.zram";
  flake.modules.nixos.zram.zramSwap.enable = true;
}
