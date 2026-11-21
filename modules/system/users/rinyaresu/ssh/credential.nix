{ config, ... }:
{
  flake.modules.nixos.rinyaresu-ssh-credential = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.rinyaresu-ssh-credential";
    imports = [ config.flake.modules.nixos.sops ];
    environment.systemPackages = [ pkgs.sops ];
    sops.validateSopsFiles = true;

    sops.secrets.rinyaresu-ssh-key = {
      sopsFile = ./secrets.yaml;
      key = "ssh_private_key";
      owner = "rinyaresu";
      group = "users";
      mode = "0600";
    };

    systemd.tmpfiles.rules = [ "d /var/lib/sops-nix 0700 root root -" ];
    systemd.services.sops-install-secrets.preStart = ''
      input=/var/lib/sops-nix/key.txt
      test -f "$input"
      test ! -L "$input"
      test -s "$input"
      test "$(${pkgs.coreutils}/bin/stat -c '%u:%g:%a' "$input")" = 0:0:600
    '';
  };
}
