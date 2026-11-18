{
  config,
  inputs,
  lib,
  ...
}:
let
  nixos = config.flake.modules.nixos;
  hosts = config.flake.nixosConfigurations;
  desktop = hosts.desktop.config;
  lab = hosts.lab.config;
  ordis = hosts.ordis.config;
  optedIn = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      nixos.nix-settings
      (import ../hosts/desktop/maintenance.nix).configurations.nixos.desktop.modules.maintenance
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        nix.gc.automatic = lib.mkForce true;
      }
    ];
  };
  nativeFirewall =
    (inputs.nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          networking.firewall.enable = true;
        }
      ];
    }).config.networking.firewall;
  overlayOnly =
    firewall:
    firewall.enable
    && firewall.allowedTCPPorts == [ ]
    && firewall.allowedTCPPortRanges == [ ]
    && firewall.allowedUDPPorts == [ ]
    && firewall.allowedUDPPortRanges == [ ]
    && builtins.attrNames firewall.interfaces == [ "tailscale0" ]
    && firewall.interfaces.tailscale0.allowedTCPPorts == [ 22 ]
    && firewall.interfaces.tailscale0.allowedTCPPortRanges == [ ]
    && firewall.interfaces.tailscale0.allowedUDPPorts == [ ]
    && firewall.interfaces.tailscale0.allowedUDPPortRanges == [ ]
    && !(builtins.elem "tailscale0" firewall.trustedInterfaces)
    && firewall.extraCommands == nativeFirewall.extraCommands;
  lanPortMutation = hosts.desktop.extendModules {
    modules = [ { networking.firewall.interfaces.lan0.allowedTCPPorts = [ 22 ]; } ];
  };
  lanCommandMutation = hosts.desktop.extendModules {
    modules = [
      {
        networking.firewall.extraCommands = lib.mkAfter ''
          iptables -A nixos-fw -i lan0 -p tcp --dport 22 -j nixos-fw-accept
        '';
      }
    ];
  };
  snapshot = desktop.services.snapper.configs.home;
  results = {
    desktop-selects-overlay = desktop.services.tailscale.enable;
    no-lab-overlay = !lab.services.tailscale.enable;
    overlay-does-not-rewrite-dns-or-firewall =
      desktop.services.tailscale.authKeyFile == null
      && !desktop.services.tailscale.openFirewall
      && desktop.services.tailscale.useRoutingFeatures == "none"
      && desktop.services.tailscale.extraSetFlags == [ ]
      && desktop.services.tailscale.extraDaemonFlags == ordis.services.tailscale.extraDaemonFlags;
    ssh-overlay-only =
      desktop.services.openssh.enable
      && !desktop.services.openssh.openFirewall
      && desktop.services.openssh.ports == [ 22 ]
      && overlayOnly desktop.networking.firewall;
    rejects-lan-port-opening = !overlayOnly lanPortMutation.config.networking.firewall;
    rejects-lan-command-opening = !overlayOnly lanCommandMutation.config.networking.firewall;
    ssh-key-only =
      desktop.services.openssh.settings.AuthenticationMethods == "publickey"
      && !desktop.services.openssh.settings.PasswordAuthentication
      && !desktop.services.openssh.settings.KbdInteractiveAuthentication
      && desktop.services.openssh.settings.PermitRootLogin == "no"
      && !desktop.services.openssh.settings.AllowAgentForwarding;
    authorization-remains-runtime-only =
      !desktop.services.openssh.authorizedKeysInHomedir
      &&
        desktop.services.openssh.authorizedKeysFiles == [
          "/var/lib/desktop-ssh/authorized_keys/%u"
        ]
      && desktop.users.users.rinyaresu.openssh.authorizedKeys.keys == [ ]
      && desktop.users.users.rinyaresu.openssh.authorizedKeys.keyFiles == [ ];
    home-only-snapshots =
      builtins.attrNames desktop.services.snapper.configs == [ "home" ]
      && snapshot.SUBVOLUME == "/home"
      && !desktop.services.snapper.snapshotRootOnBoot
      && desktop.fileSystems."/home".fsType == "btrfs";
    daily-catch-up =
      desktop.systemd.timers.snapper-timeline.timerConfig.OnCalendar == "daily"
      && desktop.systemd.timers.snapper-timeline.timerConfig.Persistent
      && builtins.elem "timers.target" desktop.systemd.timers.snapper-timeline.wantedBy;
    seven-daily-points =
      snapshot.TIMELINE_CREATE
      && snapshot.TIMELINE_CLEANUP
      && snapshot.TIMELINE_MIN_AGE == 0
      && snapshot.TIMELINE_LIMIT_DAILY == 7
      && snapshot.TIMELINE_LIMIT_HOURLY == 0
      && snapshot.TIMELINE_LIMIT_WEEKLY == 0
      && snapshot.TIMELINE_LIMIT_MONTHLY == 0
      && snapshot.TIMELINE_LIMIT_QUARTERLY == 0
      && snapshot.TIMELINE_LIMIT_YEARLY == 0;
    snapshots-stay-private = snapshot.ALLOW_USERS == [ ] && snapshot.ALLOW_GROUPS == [ ];
    maintenance-disabled-before-validation =
      !desktop.nix.gc.automatic && !(desktop.systemd.timers ? nix-gc);
    maintenance-window =
      desktop.nix.gc.dates == [ "weekly" ]
      && desktop.nix.gc.options == "--delete-older-than 30d"
      && desktop.nix.gc.persistent;
    native-opt-in-creates-weekly-timer =
      optedIn.config.nix.gc.automatic
      && optedIn.config.systemd.timers.nix-gc.timerConfig.OnCalendar == [ "weekly" ]
      && optedIn.config.systemd.timers.nix-gc.timerConfig.Persistent;
    other-hosts-keep-manual-maintenance = !lab.nix.gc.automatic && !ordis.nix.gc.automatic;
    other-hosts-have-no-home-snapshot-policy =
      lab.services.snapper.configs == { } && ordis.services.snapper.configs == { };
  };
  failures = builtins.attrNames (lib.filterAttrs (_: value: !value) results);
in
{
  perSystem = { pkgs, ... }: {
    checks.desktop-policies =
      assert lib.assertMsg (
        failures == [ ]
      ) "Desktop policy checks failed: ${lib.concatStringsSep ", " failures}";
      pkgs.writeText "desktop-policy-checks.json" (builtins.toJSON results);
    checks.desktop-access = pkgs.testers.runNixOSTest (
      import ../../checks/desktop-access.nix {
        inherit nixos;
        firewallExtraCommands = desktop.networking.firewall.extraCommands;
      }
    );
    checks.desktop-snapshots = pkgs.testers.runNixOSTest (
      import ../../checks/desktop-snapshots.nix { inherit nixos; }
    );
  };
}
