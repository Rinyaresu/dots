{
  configurations.nixos.desktop.modules.configuration = { config, ... }: {
    imports = [ ./_hardware-configuration.nix ];

    assertions = [
      {
        assertion = !config.services.pihole-ftl.enable;
        message = "The desktop must not run Pi-hole.";
      }
    ];

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
        path: guid(${(import ./_disko-inventory.nix).windowsEsp}):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
