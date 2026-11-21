{
  nixos,
  homeManager,
  pkgs,
}:
pkgs.testers.runNixOSTest {
  name = "secret-runtime";
  nodes.machine = { config, ... }: {
    imports = [
      nixos.home-manager
      nixos.rinyaresu-ssh
    ];
    users.users = {
      rinyaresu = {
        isNormalUser = true;
        uid = 1000;
      };
      observer = {
        isNormalUser = true;
        uid = 1001;
      };
    };
    home-manager.users.rinyaresu = {
      imports = [ homeManager.rinyaresu-ssh ];
      home.stateVersion = "26.05";
    };
    environment.etc = {
      "secret-runtime-manifest.json".source = config.system.build.sops-nix-manifest;
      "secret-runtime-activation".source = config.home-manager.users.rinyaresu.home.activationPackage;
      "secret-runtime-ciphertext".source = config.sops.secrets.rinyaresu-ssh-key.sopsFile;
    };
    environment.systemPackages = [
      pkgs.age
      pkgs.openssh
      pkgs.python3
    ];
    virtualisation.memorySize = 1024;
  };
  testScript = builtins.readFile ./secret-runtime.py;
}
