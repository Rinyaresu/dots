inventory:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  target = "/dev/disk/by-id/${inventory.byId}";
  # Fixed GPT identities on the *new* Linux disk; neither is a Windows partition.
  esp = "8b5286b7-87ff-447f-b2ae-f7d3665b0c22";
  root = "c552e5a9-c77a-444c-aa30-7cb1f1fd21bf";
  guard = pkgs.writeShellApplication {
    name = "desktop-disk-guard";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      jq
      util-linux
      systemd
    ];
    text = ''
      target=${lib.escapeShellArg target}
      expected_id=${lib.escapeShellArg (lib.removePrefix "ata-" (lib.removePrefix "virtio-" inventory.byId))}
      expected_model=${lib.escapeShellArg inventory.model}
      expected_bytes=${toString inventory.bytes}
      old_esp=${inventory.originalEsp}
      old_root=${inventory.originalRoot}
      windows_esp=${inventory.windowsEsp}
      esp=${esp}
      root=${root}
      mount_root=${lib.escapeShellArg config.disko.rootMountPoint}
    ''
    + builtins.readFile ./_disko-guard.sh;
  };
  check = lib.getExe guard;
  # exec is necessary: Disko only sets errexit later, in its create script.
  disabledDestroy = ''
    # shellcheck disable=SC2093
    exec ${check} refuse-destroy
  '';
  subvolume = mountpoint: {
    inherit mountpoint;
    mountOptions = [ "compress=zstd" ];
  };
in
{
  system.build.desktopDiskGuard = guard;
  disko = {
    checkScripts = true;
    # Disko's generic destroy can unmount /mnt wholesale and has no pre-destroy
    # hook. Refuse both modern and legacy entry points. The disk's create hook
    # instead wipes signatures only on the two verified old partitions and disk.
    devices._destroy = disabledDestroy;
    devices._legacyDestroy = disabledDestroy;
    devices.disk.linux = {
      type = "disk";
      device = target;
      destroy = false;
      preCreateHook = "${check} wipe";
      preMountHook = "${check} installed";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "4G";
            type = "EF00";
            uuid = esp;
            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-F"
                "32"
                "-n"
                "NIXOS_BOOT"
              ];
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
              preCreateHook = "${check} partition ${esp}";
            };
          };
          nixos = {
            priority = 2;
            size = "100%";
            uuid = root;
            content = {
              type = "btrfs";
              extraArgs = [
                "-L"
                "NIXOS"
              ];
              preCreateHook = "${check} partition ${root}";
              subvolumes = {
                "@" = subvolume "/";
                "@home" = subvolume "/home";
                "@nix" = subvolume "/nix";
              };
            };
          };
        };
      };
    };
  };
}
