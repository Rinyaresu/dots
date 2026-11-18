{
  configurations.nixos.desktop.modules.hardware = { lib, ... }: {
    nixpkgs.hostPlatform = "x86_64-linux";
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.amd.updateMicrocode = true;
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    boot.kernelModules = [ "kvm-amd" ];
    services.xserver.videoDrivers = [ "amdgpu" ];
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-label/NIXOS";
        fsType = "btrfs";
        options = [
          "subvol=@"
          "compress=zstd"
        ];
      };
      "/home" = {
        device = "/dev/disk/by-label/NIXOS";
        fsType = "btrfs";
        options = [
          "subvol=@home"
          "compress=zstd"
        ];
      };
      "/nix" = {
        device = "/dev/disk/by-label/NIXOS";
        fsType = "btrfs";
        options = [
          "subvol=@nix"
          "compress=zstd"
        ];
      };
      "/boot" = {
        device = "/dev/disk/by-label/NIXOS_BOOT";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };
    swapDevices = lib.mkForce [ ];
  };
}
