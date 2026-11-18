{
  configurations.nixos.lab.modules.configuration = { config, lib, ... }: {
    nixpkgs.hostPlatform = "x86_64-linux";
    networking.hostName = "nixos-lab";
    system.stateVersion = "26.05";
    boot.loader.timeout = 5;
    console.useXkbConfig = true;
    networking.useDHCP = false;
    networking.dhcpcd.enable = false;
    users.users.rinyaresu.initialPassword = "nixos";
    virtualisation = {
      memorySize = 4096;
      cores = 2;
      diskSize = 8192;
      mountHostNixStore = false;
      useNixStoreImage = true;
      writableStore = true;
      writableStoreUseTmpfs = false;
      sharedDirectories = lib.mkForce { };
      restrictNetwork = true;
      qemu.networkingOptions = lib.mkForce [ "-nic none" ];
    };
    assertions = [
      {
        assertion =
          !config.virtualisation.mountHostNixStore
          && config.virtualisation.useNixStoreImage
          && config.virtualisation.sharedDirectories == { }
          && config.virtualisation.restrictNetwork
          && config.virtualisation.qemu.networkingOptions == [ "-nic none" ];
        message = "The lab requires a separate store image, no shared directories and no network.";
      }
      {
        assertion =
          (config.sops.secrets or { }) == { }
          && !config.services.tailscale.enable
          && !(config.home-manager.users.rinyaresu.systemd.user.services ? pi-config-restore);
        message = "The lab must not receive personal secrets, bootstrap or overlay access.";
      }
    ];
  };
}
