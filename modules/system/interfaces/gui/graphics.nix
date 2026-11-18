{
  flake.modules.nixos.gui.key = "${__curPos.file}#nixos.graphics";
  flake.modules.nixos.gui.hardware.graphics.enable = true;
}
