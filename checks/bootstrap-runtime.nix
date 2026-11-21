{
  nixos,
  homeManager,
  pkgs,
}:
let
  askpass = pkgs.writeShellScript "bootstrap-runtime-askpass" ''
    echo prompt >> "$HOME/bootstrap-prompts"
    echo disposable-bootstrap-passphrase
  '';
in
pkgs.testers.runNixOSTest {
  name = "bootstrap-runtime";
  nodes.machine =
    { config, lib, ... }:
    {
      imports = [
        nixos.home-manager
        nixos.rinyaresu-ssh
        nixos.pi-bootstrap
      ];
      users.users = {
        rinyaresu = {
          isNormalUser = true;
          uid = 1000;
        };
        fixturegit = {
          isNormalUser = true;
          home = "/srv/git";
        };
      };
      home-manager.users.rinyaresu = {
        imports = [
          homeManager.rinyaresu-ssh
          homeManager.pi-bootstrap
        ];
        home.stateVersion = "26.05";
      };
      services.openssh = {
        enable = true;
        openFirewall = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
      programs.ssh.askPassword = lib.mkForce "${askpass}";
      environment.etc."bootstrap-runtime-manifest.json".source = config.system.build.sops-nix-manifest;
      environment.etc."bootstrap-dependency-fixture.sh".source = ./bootstrap-dependency-fixture.sh;
      environment.etc."bootstrap-pi-imports.mjs".source = ./pi-local-extension-check.mjs;
      environment.systemPackages = [
        pkgs.age
        pkgs.efibootmgr
        pkgs.nodejs_24
        pkgs.git
        pkgs.openssh
        pkgs.python3
      ];
      virtualisation = {
        memorySize = 2048;
        vlans = [ ];
      };
    };
  testScript = builtins.readFile ./bootstrap-runtime.py;
}
