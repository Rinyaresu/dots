{
  flake.modules.nixos.host-desktop = { lib, ... }: {
    services.openssh = {
      enable = true;
      openFirewall = false;
      ports = [ 22 ];
      authorizedKeysInHomedir = false;
      authorizedKeysFiles = lib.mkForce [ "/var/lib/desktop-ssh/authorized_keys/%u" ];
      settings = {
        AuthenticationMethods = "publickey";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowAgentForwarding = false;
        AllowUsers = [ "rinyaresu" ];
        StrictModes = true;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    systemd.tmpfiles.rules = [
      "d /var/lib/desktop-ssh 0755 root root -"
      "d /var/lib/desktop-ssh/authorized_keys 0755 root root -"
    ];
  };
}
