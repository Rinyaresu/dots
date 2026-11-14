{ inputs, ... }:
{
  configurations.nixos.ordis.modules.configuration = { pkgs, ... }: {
    networking.hostName = "ordis";
    networking.networkmanager.enable = true;
    networking.firewall.enable = true;

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
    security.sudo.wheelNeedsPassword = true;

    time.timeZone = "America/Sao_Paulo";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_MEASUREMENT = "pt_BR.UTF-8";
      LC_MONETARY = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_NUMERIC = "pt_BR.UTF-8";
      LC_PAPER = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
      LC_TIME = "pt_BR.UTF-8";
    };
    services.xserver.xkb = {
      layout = "us";
      variant = "intl";
    };
    console.keyMap = "us-acentos";

    zramSwap.enable = false;
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.gc.automatic = false;
    system.autoUpgrade.enable = false;
    system.stateVersion = "26.05";
  };
}
