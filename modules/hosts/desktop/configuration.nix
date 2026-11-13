{
  configurations.nixos.desktop.modules.configuration = {
    networking.hostName = "desktop";
    boot.loader.limine.extraEntries = ''
      /Windows
        protocol: efi
        path: guid(659c8b2d-2d7d-4b8a-82dd-ca519a94eb0c):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
