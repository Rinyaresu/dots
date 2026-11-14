{ config, ... }:
{
  flake.modules.nixos.host-ordis = { pkgs, ... }: {
    imports = with config.flake.modules.nixos; [
      nix-settings
      networking
      locale
      sudo
    ];
    networking.hostName = "ordis";

    boot.initrd.systemd.enable = true;
    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = null;
      efi.canTouchEfiVariables = true;
      timeout = 5;
    };

    services.openssh = {
      enable = true;
      openFirewall = true;
      ports = [ 22 ];
      settings = {
        PasswordAuthentication = true;
        KbdInteractiveAuthentication = true;
        PermitRootLogin = "prohibit-password";
      };
    };

    users.mutableUsers = true;
    users.users.ordis = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      home = "/home/ordis";
      description = "ordis";
      shell = pkgs.bashInteractive;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGR8PisAMuRe4mb+K8jCh+W0CLa8vcLElsLN0ECaY8fU"
      ];
    };
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
    };
    console.keyMap = "us-acentos";

    zramSwap.enable = false;
    nixpkgs.config.allowUnfree = true;
    system.stateVersion = "26.05";
  };
}
