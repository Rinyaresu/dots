{
  flake.modules.nixos.no-hibernation.key = "${__curPos.file}#nixos.no-hibernation";
  flake.modules.nixos.no-hibernation.systemd.sleep.settings.Sleep = {
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
}
