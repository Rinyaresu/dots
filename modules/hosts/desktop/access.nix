{
  configurations.nixos.desktop.modules.access =
    { config, lib, ... }:
    let
      ssh = config.services.openssh;
      firewall = config.networking.firewall;
      account = config.users.users.rinyaresu;
    in
    {
      assertions = [
        {
          assertion =
            ssh.enable
            && !ssh.openFirewall
            && ssh.ports == [ 22 ]
            && firewall.enable
            && firewall.extraInputRules == ""
            && firewall.allowedTCPPorts == [ ]
            && firewall.allowedTCPPortRanges == [ ]
            && firewall.allowedUDPPorts == [ ]
            && firewall.allowedUDPPortRanges == [ ]
            && builtins.attrNames firewall.interfaces == [ "tailscale0" ]
            && firewall.interfaces.tailscale0.allowedTCPPorts == [ 22 ]
            && firewall.interfaces.tailscale0.allowedTCPPortRanges == [ ]
            && firewall.interfaces.tailscale0.allowedUDPPorts == [ ]
            && firewall.interfaces.tailscale0.allowedUDPPortRanges == [ ]
            && lib.all (interface: interface == "lo") firewall.trustedInterfaces;
          message = "Desktop SSH must be admitted only through tailscale0 by the firewall.";
        }
        {
          assertion =
            ssh.settings.AuthenticationMethods == "publickey"
            && !ssh.settings.PasswordAuthentication
            && !ssh.settings.KbdInteractiveAuthentication
            && ssh.settings.PermitRootLogin == "no"
            && !ssh.settings.AllowAgentForwarding
            && ssh.settings.AllowUsers == [ "rinyaresu" ]
            && ssh.settings.StrictModes
            && !ssh.authorizedKeysInHomedir
            && ssh.authorizedKeysFiles == [ "/var/lib/desktop-ssh/authorized_keys/%u" ]
            && account.openssh.authorizedKeys.keys == [ ]
            && account.openssh.authorizedKeys.keyFiles == [ ];
          message = "Desktop SSH requires public keys provisioned at runtime for the non-root account.";
        }
      ];

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
