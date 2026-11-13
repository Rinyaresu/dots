{
  flake.modules.nixos.base.boot.loader.timeout = 5;

  flake.modules.nixos.limine = {
    boot = {
      initrd.systemd.enable = true;
      loader = {
        efi.canTouchEfiVariables = true;
        limine = {
          enable = true;
          efiSupport = true;
          enableEditor = false;
          validateChecksums = true;
          panicOnChecksumMismatch = true;
          enrollConfig = true;
          secureBoot.enable = false;
        };
      };
    };
  };
}
