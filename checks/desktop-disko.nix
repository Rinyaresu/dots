{
  pkgs,
  inputs,
  desktop,
}:
let
  inherit (pkgs) lib;
  layout = import ../modules/hosts/desktop/_disko-layout.nix;
  actual = import ../modules/hosts/desktop/_disko-inventory.nix;
  inventory = {
    byId = "virtio-dots-linux";
    model = "";
    bytes = 5 * 1024 * 1024 * 1024;
    originalEsp = "1b1606bd-e01a-4874-ae42-6c4289f089c3";
    originalRoot = "63a0cf9b-7d29-4c89-bd02-7e57a32c43e0";
    windowsEsp = "b77935ae-56c0-48c2-9930-012cf868af62";
  };
  evaluate =
    inv:
    (inputs.nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        inputs.disko.nixosModules.disko
        (layout inv)
        { system.stateVersion = "26.05"; }
      ];
    }).config;
  virtual = evaluate inventory;
  repeated = evaluate inventory;
  protected = evaluate (
    inventory
    // {
      byId = "virtio-dots-windows";
      bytes = 256 * 1024 * 1024;
    }
  );
  wrong = evaluate (inventory // { bytes = inventory.bytes + 512; });
  fsProjection =
    cfg:
    lib.genAttrs [ "/" "/home" "/nix" "/boot" ] (path: {
      inherit (cfg.fileSystems.${path}) device fsType options;
      luks = cfg.fileSystems.${path}.encrypted.enable;
    });
  format = cfg: "${cfg.system.build.formatMount}/bin/disko-format-mount";
  guard = lib.getExe virtual.system.build.desktopDiskGuard;
  mount = "${virtual.system.build.mount}/bin/disko-mount";
in
assert builtins.attrNames desktop.disko.devices.disk == [ "linux" ];
assert desktop.disko.devices.disk.linux.device == "/dev/disk/by-id/${actual.byId}";
assert fsProjection virtual == fsProjection desktop;
assert fsProjection repeated == fsProjection virtual;
assert format repeated == format virtual;
pkgs.testers.runNixOSTest {
  name = "desktop-disko";
  nodes.installer = {
    system.stateVersion = "26.05";
    virtualisation = {
      emptyDiskImages = [
        {
          size = 5120;
          driveConfig.deviceExtraOpts.serial = "dots-linux";
        }
        {
          size = 256;
          driveConfig.deviceExtraOpts.serial = "dots-windows";
        }
      ];
      memorySize = 2048;
      cores = 2;
      useNixStoreImage = true;
      restrictNetwork = true;
      vlans = lib.mkForce [ ];
      qemu.forceAccel = lib.mkForce true;
      qemu.networkingOptions = lib.mkForce [ ];
    };
    environment.systemPackages = with pkgs; [
      btrfs-progs
      dosfstools
      gptfdisk
      mtools
      parted
    ];
  };
  testScript = ''
    import json

    inventory = json.loads('${builtins.toJSON inventory}')
    filesystems = json.loads('${builtins.toJSON (fsProjection virtual)}')
    format_linux = "${format virtual}"
    format_windows = "${format protected}"
    format_wrong = "${format wrong}"
    guard = "${guard}"
    mount_linux = "${mount}"
    destroy = "${virtual.system.build.destroyFormatMount}/bin/disko-destroy-format-mount"
    legacy_destroy = "${virtual.system.build.diskoScript}"
    ${builtins.readFile ./desktop-disko.py}
  '';
}
