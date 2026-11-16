{ config, ... }:
let
  nixos = config.flake.modules.nixos;
in
{
  flake.modules.nixos.rinyaresu-ssh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      key = "${__curPos.file}#nixos.rinyaresu-ssh";
      imports = [ nixos.sops ];
      environment.systemPackages = [ pkgs.sops ];
      sops.validateSopsFiles = true;
      sops.secrets.rinyaresu-ssh-key = {
        sopsFile = ../../../secrets/ssh.yaml;
        key = "ssh_private_key";
        owner = "rinyaresu";
        group = "users";
        mode = "0600";
      };
      systemd.tmpfiles.rules = [
        "d /home/rinyaresu/.ssh 0700 rinyaresu users -"
        "d /var/lib/sops-nix 0700 root root -"
      ];
      systemd.services.sops-install-secrets.preStart = ''
        input=/var/lib/sops-nix/key.txt
        test -f "$input"
        test ! -L "$input"
        test -s "$input"
        test "$(${pkgs.coreutils}/bin/stat -c '%u:%g:%a' "$input")" = 0:0:600
      '';
      systemd.services.home-manager-rinyaresu = {
        after = lib.mkAfter [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
      };
      assertions = [
        {
          assertion =
            (config.users.users.rinyaresu.isNormalUser or false)
            && (config.home-manager.users.rinyaresu.home.username or null) == "rinyaresu";
          message = "rinyaresu-ssh requires the rinyaresu account and its Home Manager configuration.";
        }
      ];
    };

  flake.modules.homeManager.rinyaresu-ssh = { config, osConfig, ... }: {
    key = "${__curPos.file}#homeManager.rinyaresu-ssh";
    assertions = [
      {
        assertion =
          config.home.username == "rinyaresu"
          && (osConfig ? sops)
          && (osConfig.sops.secrets ? rinyaresu-ssh-key);
        message = "The personal SSH link requires the rinyaresu account and its NixOS secret.";
      }
    ];
    home.file.".ssh/id_ed25519".source =
      config.lib.file.mkOutOfStoreSymlink "/run/secrets/rinyaresu-ssh-key";
  };
}
