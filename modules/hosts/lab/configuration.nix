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
        assertion = !config.virtualisation.mountHostNixStore;
        message = "The lab must not mount the host store.";
      }
    ];
  };
}
