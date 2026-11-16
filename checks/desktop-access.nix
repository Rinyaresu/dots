{ nixos, firewallExtraCommands }:
{
  name = "desktop-overlay-access";
  nodes.machine = { lib, pkgs, ... }: {
    imports = [
      nixos.networking
      nixos.tailscale
      (import ../modules/hosts/desktop/access.nix).flake.modules.nixos.host-desktop
    ];
    networking.firewall.extraCommands = lib.mkForce firewallExtraCommands;
    virtualisation.vlans = lib.mkForce [ ];
    virtualisation.restrictNetwork = true;
    networking.networkmanager.unmanaged = [
      "interface-name:lan0"
      "interface-name:wan0"
      "interface-name:tailscale0"
    ];
    users.users.rinyaresu = {
      isNormalUser = true;
      initialPassword = "fixture-only";
    };
    environment.systemPackages = [
      pkgs.curl
      pkgs.iproute2
      pkgs.netcat-openbsd
      pkgs.openssh
    ];
  };
  testScript = builtins.readFile ./desktop-access.py;
}
