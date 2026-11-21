{ lib, ... }: {
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
  # The desktop storage module (Disko) owns fileSystems.
  swapDevices = lib.mkForce [ ];
}
