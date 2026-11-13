{ inputs, ... }:
{
  flake.modules.nixos.secrets =
    { config, lib, ... }:
    let
      enabled = config.sops.secrets ? rinyaresu-ssh-key;
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops = {
        useSystemdActivation = true;
        age = {
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = false;
          sshKeyPaths = [ ];
        };
        gnupg.sshKeyPaths = [ ];
      };
      systemd.tmpfiles.rules = lib.optionals enabled [
        "d /home/rinyaresu/.ssh 0700 rinyaresu users -"
      ];
      systemd.services.home-manager-rinyaresu = lib.mkIf enabled {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };
    };

  flake.modules.homeManager.secrets =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    lib.mkIf (osConfig.sops.secrets ? rinyaresu-ssh-key) {
      home.file.".ssh/id_ed25519".source =
        config.lib.file.mkOutOfStoreSymlink "/run/secrets/rinyaresu-ssh-key";
    };

  flake.modules.nixos.personal-secrets = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.sops ];
    sops.secrets.rinyaresu-ssh-key = {
      sopsFile = ../../secrets/ssh.yaml;
      key = "ssh_private_key";
      owner = "rinyaresu";
      group = "users";
      mode = "0600";
    };
  };
}
