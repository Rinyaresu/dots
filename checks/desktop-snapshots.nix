{ nixos }:
{
  name = "desktop-home-snapshots";
  nodes.machine = { lib, pkgs, ... }: {
    imports = [
      nixos.home-snapshots
      nixos.nix-settings
      (import ../modules/hosts/desktop/maintenance.nix).configurations.nixos.desktop.modules.maintenance
    ];
    virtualisation.restrictNetwork = true;
    virtualisation.vlans = lib.mkForce [ ];
    virtualisation.emptyDiskImages = [
      {
        size = 1024;
        driveConfig.deviceExtraOpts.serial = "home-fixture";
      }
    ];
    virtualisation.fileSystems."/home" = {
      device = "/dev/disk/by-id/virtio-home-fixture";
      fsType = "btrfs";
      autoFormat = true;
    };
    users.users.alice.isNormalUser = true;
    services.timesyncd.enable = false;
    time.timeZone = "UTC";
    systemd.timers.snapper-timeline.wantedBy = lib.mkForce [ ];
    systemd.timers.snapper-cleanup.wantedBy = lib.mkForce [ ];
    environment.systemPackages = [ pkgs.python3 ];
  };
  testScript = builtins.readFile ./desktop-snapshots.py;
}
