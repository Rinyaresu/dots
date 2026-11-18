{
  flake.modules.nixos.wireguard = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.wireguard";
    environment.systemPackages = [ pkgs.wireguard-tools ];
  };
}
