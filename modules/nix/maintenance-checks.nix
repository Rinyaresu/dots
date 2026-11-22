{
  config,
  lib,
  ...
}:
let
  inherit (config.flake.nixosConfigurations) desktop ordis lab;
  desktopCfg = desktop.config;
  ordisCfg = ordis.config;
  labCfg = lab.config;
  weeklyPersistent =
    timer: timer.timerConfig.OnCalendar == [ "weekly" ] && timer.timerConfig.Persistent;
  monitorsAndScrubs =
    cfg:
    cfg.services.smartd.enable
    && cfg.services.smartd.autodetect
    && cfg.services.btrfs.autoScrub.fileSystems == [ "/" ]
    && cfg.systemd.timers."btrfs-scrub--".timerConfig.OnCalendar == "monthly";
in
{
  perSystem = { pkgs, ... }: {
    checks.host-maintenance =
      assert desktopCfg.zramSwap.enable;
      assert desktopCfg.zramSwap.algorithm == "zstd";
      assert desktopCfg.zramSwap.memoryPercent == 100;
      assert desktopCfg.swapDevices == [ ];
      assert desktopCfg.services.fstrim.enable && desktopCfg.services.fstrim.interval == "weekly";
      assert monitorsAndScrubs desktopCfg;
      assert weeklyPersistent desktopCfg.systemd.timers.nix-gc;
      assert lib.hasSuffix " --delete-older-than 30d" desktopCfg.systemd.services.nix-gc.script;
      assert ordisCfg.zramSwap.enable;
      assert ordisCfg.zramSwap.algorithm == "zstd";
      assert ordisCfg.zramSwap.memoryPercent == 50;
      assert
        ordisCfg.zramSwap.priority > 0
        &&
          map (swap: swap.device) ordisCfg.swapDevices == [
            "/dev/disk/by-uuid/d00e945f-6814-4b1d-b11a-3f1af3e9e99e"
          ];
      assert monitorsAndScrubs ordisCfg;
      assert weeklyPersistent ordisCfg.systemd.timers.ordis-nix-gc;
      assert !(ordisCfg.systemd.timers ? nix-gc);
      assert !(labCfg.systemd.timers ? nix-gc);
      pkgs.runCommand "host-maintenance-check" { } ''
        ${pkgs.python3}/bin/python3 ${../../checks/ordis-system-gc.py} \
          ${../hosts/ordis/_system-gc.py} ${ordisCfg.nix.package}/bin "$TMPDIR"
        touch "$out"
      '';
  };
}
