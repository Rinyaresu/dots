{
  flake.modules.nixos.networking = {
    key = "${__curPos.file}#nixos.networking";
    networking.firewall.enable = true;
    networking.networkmanager.enable = true;
  };
}
