{
  flake.modules.nixos.gui.key = "${__curPos.file}#nixos.bluetooth";
  flake.modules.nixos.gui.hardware.bluetooth.enable = true;
}
