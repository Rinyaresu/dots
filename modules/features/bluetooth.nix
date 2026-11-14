{
  flake.modules.nixos.bluetooth.key = "${__curPos.file}#nixos.bluetooth";
  flake.modules.nixos.bluetooth.hardware.bluetooth.enable = true;
}
