{
  configurations.nixos.desktop.modules.configuration = {
    networking.hostName = "desktop";
    system.stateVersion = "26.05";
    boot.loader.timeout = 5;
    console.useXkbConfig = true;
    boot.kernelParams = [ "usbcore.autosuspend=-1" ];
    zramSwap = {
      memoryPercent = 100;
      algorithm = "zstd";
    };
    hardware.bluetooth.powerOnBoot = true;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "pt_BR.UTF-8";
      LC_IDENTIFICATION = "pt_BR.UTF-8";
      LC_NAME = "pt_BR.UTF-8";
      LC_TELEPHONE = "pt_BR.UTF-8";
    };
    boot.loader.limine.extraEntries = ''
      /Windows
        protocol: efi
        path: guid(659c8b2d-2d7d-4b8a-82dd-ca519a94eb0c):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
