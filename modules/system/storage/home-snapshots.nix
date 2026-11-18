{
  flake.modules.nixos.home-snapshots = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.home-snapshots";

    services.snapper = {
      snapshotRootOnBoot = false;
      snapshotInterval = "daily";
      persistentTimer = true;
      configs.home = {
        SUBVOLUME = "/home";
        FSTYPE = "btrfs";
        ALLOW_USERS = [ ];
        ALLOW_GROUPS = [ ];
        SYNC_ACL = false;
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_MIN_AGE = 0;
        TIMELINE_LIMIT_HOURLY = 0;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_QUARTERLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };

    systemd.services.home-snapshots-prepare = {
      description = "Prepare private home snapshot storage";
      unitConfig.RequiresMountsFor = "/home";
      before = [
        "snapper-timeline.service"
        "snapper-cleanup.service"
      ];
      path = [
        pkgs.btrfs-progs
        pkgs.coreutils
      ];
      script = ''
        set -eu
        btrfs subvolume show /home >/dev/null
        if [ ! -e /home/.snapshots ]; then
          btrfs subvolume create /home/.snapshots
        fi
        btrfs subvolume show /home/.snapshots >/dev/null
        chown root:root /home/.snapshots
        chmod 0700 /home/.snapshots
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.snapper-timeline = {
      requires = [ "home-snapshots-prepare.service" ];
      after = [ "home-snapshots-prepare.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPost = "${pkgs.snapper}/bin/snapper --config home cleanup timeline";
      };
    };

    systemd.services.snapper-cleanup = {
      requires = [ "home-snapshots-prepare.service" ];
      after = [ "home-snapshots-prepare.service" ];
      serviceConfig.Type = "oneshot";
    };
  };
}
