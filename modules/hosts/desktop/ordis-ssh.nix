let
  ordisLanAddress = "192.168.1.196";
in
{
  configurations.nixos.desktop.modules.ordis-ssh = {
    programs.ssh = {
      # ED25519 host key verified on the physical Ordis console.
      knownHosts.${ordisLanAddress}.publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPU0mzhyUqXgqps22eM5RQ2foTfVzbTdpvyEWYWDMbyy";

      extraConfig = ''
        Host ordis
          HostName ${ordisLanAddress}
          User ordis

        Host ordis ${ordisLanAddress}
          StrictHostKeyChecking yes
          PreferredAuthentications publickey
      '';
    };
  };
}
