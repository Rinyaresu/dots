{ config, ... }:
let
  nixos = config.flake.modules.nixos;
in
{
  flake.modules.nixos.rinyaresu-ssh =
    {
      config,
      lib,
      ...
    }:
    {
      key = "${__curPos.file}#nixos.rinyaresu-ssh";
      imports = [
        nixos.rinyaresu-ssh-credential
      ];
      systemd.tmpfiles.rules = [
        "d /home/rinyaresu/.ssh 0700 rinyaresu users -"
      ];
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
      config.lib.file.mkOutOfStoreSymlink osConfig.sops.secrets.rinyaresu-ssh-key.path;
  };

  flake.modules.nixos.desktop-personal = {
    imports = [ config.flake.modules.nixos.rinyaresu-ssh ];
  };
  flake.modules.homeManager.desktop-personal = {
    imports = [ config.flake.modules.homeManager.rinyaresu-ssh ];
  };
}
