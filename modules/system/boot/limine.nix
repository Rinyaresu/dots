{
  flake.modules.nixos.limine = { lib, pkgs, ... }: {
    key = "${__curPos.file}#nixos.limine";
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "windows";
        runtimeInputs = with pkgs; [
          gawk
          systemd
        ];
        text = builtins.replaceStrings [ "@efibootmgr@" ] [ (lib.getExe pkgs.efibootmgr) ] (
          builtins.readFile ./windows.sh
        );
      })
    ];
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
