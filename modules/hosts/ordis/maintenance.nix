{
  configurations.nixos.ordis.modules.maintenance =
    {
      config,
      pkgs,
      utils,
      ...
    }:
    let
      bootMount =
        if config.boot.loader.systemd-boot.xbootldrMountPoint != null then
          config.boot.loader.systemd-boot.xbootldrMountPoint
        else
          config.boot.loader.efi.efiSysMountPoint;
    in
    {
      zramSwap = {
        algorithm = "zstd";
        memoryPercent = 50;
      };

      services.smartd = {
        enable = true;
        defaults.monitored = "-a -s L/../15/./03";
      };
      services.btrfs.autoScrub.enable = true;

      assertions = [
        {
          assertion = !config.nix.gc.automatic && !(config.systemd.timers ? nix-gc);
          message = "Ordis must use ordis-nix-gc for automatic collection to preserve system generations.";
        }
        {
          assertion = config.boot.loader.systemd-boot.enable;
          message = "Ordis generation retention requires systemd-boot entries.";
        }
      ];

      systemd.services.ordis-nix-gc = {
        description = "Collect Nix garbage after retaining recoverable system generations";
        startAt = "weekly";
        restartIfChanged = false;
        unitConfig = {
          RequiresMountsFor = [
            "/nix"
            bootMount
          ];
          AssertPathIsMountPoint = [
            "/nix"
            bootMount
          ];
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = utils.escapeSystemdExecArgs [
            "${pkgs.python3}/bin/python3"
            "${./_system-gc.py}"
            "${config.nix.package}/bin"
            "local"
            "/nix/var/nix/profiles/system"
            bootMount
            "/run"
          ];
        };
      };
      systemd.timers.ordis-nix-gc.timerConfig.Persistent = true;
    };
}
