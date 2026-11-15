{ config, ... }:
{
  flake.modules.nixos.host-ordis = { pkgs, ... }: {
    imports = with config.flake.modules.nixos; [
      nix-settings
      networking
      locale
      sudo
      tailscale
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
      openFirewall = false;
      ports = [ 22 ];
      settings = {
        AuthenticationMethods = "publickey";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowAgentForwarding = false;
      };
    };

    networking.firewall = {
      # Only OpenSSH on the private overlay, never all ports on tailscale0.
      interfaces.tailscale0.allowedTCPPorts = [ 22 ];
      # Source AND destination matter: eno1 also carries globally routable IPv6.
      # LAN administration uses IPv4; no physical-interface IPv6 SSH exception.
      extraCommands = ''
        iptables -A nixos-fw -i eno1 -s 192.168.1.65/32 -d 192.168.1.196/32 -p tcp --dport 22 -j nixos-fw-accept
      '';
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
