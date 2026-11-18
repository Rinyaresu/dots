{ inputs, ... }:
{
  flake.modules.nixos.sops = {
    key = "${__curPos.file}#nixos.sops";
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
  };
}
