{
  config,
  inputs,
  lib,
  ...
}:
let
  nixos = config.flake.modules.nixos;
  home = config.flake.modules.homeManager;
  hosts = config.flake.nixosConfigurations;
  desktop = hosts.desktop.config;
  lab = hosts.lab.config;
  ordis = hosts.ordis.config;
  fixture =
    extra:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        nixos.home-manager
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "26.05";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          users.users = {
            alice = {
              isNormalUser = true;
              home = "/srv/alice";
            };
            bob.isNormalUser = true;
          };
          home-manager.users = {
            alice = {
              home.stateVersion = "26.05";
              imports = [
                home.git
                home.ghostty
                home.ghostty
              ];
            };
            bob = {
              home.stateVersion = "25.11";
              imports = [ home.fish ];
            };
          };
        }
      ]
      ++ extra;
    };
  good = fixture [ ];
  repeatedPi = fixture [
    {
      home-manager.users.alice.imports = [
        home.pi
        home.pi
      ];
    }
  ];
  alice = good.config.home-manager.users.alice;
  bob = good.config.home-manager.users.bob;
  rejects =
    modules:
    !(builtins.tryEval (builtins.deepSeq (fixture modules).config.system.build.toplevel.drvPath true))
    .success;
  results = {
    fixture-evaluates = builtins.isString good.config.system.build.toplevel.drvPath;
    separate-identities = alice.home.username == "alice" && bob.home.username == "bob";
    native-home-paths =
      alice.home.homeDirectory == "/srv/alice" && bob.home.homeDirectory == "/home/bob";
    independent-state-versions = alice.home.stateVersion == "26.05" && bob.home.stateVersion == "25.11";
    no-forced-uid = good.config.users.users.alice.uid == null;
    home-only-selection =
      alice.programs.git.enable && alice.programs.ghostty.enable && !bob.programs.ghostty.enable;
    separate-shells = !alice.programs.fish.enable && bob.programs.fish.enable;
    overlapping-imports =
      alice.programs.ghostty.settings.theme == [ "Rose Pine Dawn" ]
      && alice.programs.ghostty.settings.font-family == [ "Iosevka Nerd Font" ];
    repeated-pi-publication =
      builtins.length (
        builtins.filter (
          p: (p.pname or "") == "pi"
        ) repeatedPi.config.home-manager.users.alice.home.packages
      ) == 1;
    real-ghostty-diamonds =
      builtins.all
        (
          c:
          c.home-manager.users.rinyaresu.programs.ghostty.settings.theme == [ "Rose Pine Dawn" ]
          && c.home-manager.users.rinyaresu.programs.ghostty.settings.font-family == [ "Iosevka Nerd Font" ]
        )
        [
          desktop
          lab
        ];
    real-pi-single-occurrence =
      builtins.all
        (
          c:
          builtins.length (
            builtins.filter (p: (p.pname or "") == "pi") c.home-manager.users.rinyaresu.home.packages
          ) == 1
        )
        [
          desktop
          lab
        ];
    reject-wrong-class = rejects [ home.ghostty ];
    reject-missing-account = rejects [ { home-manager.users.unknown.home.stateVersion = "26.05"; } ];
    reject-wrong-identity = rejects [ { home-manager.users.alice.home.username = lib.mkForce "bob"; } ];
    reject-wrong-home = rejects [
      { home-manager.users.alice.home.homeDirectory = lib.mkForce "/wrong"; }
    ];
    reject-i3-without-system = rejects [ { home-manager.users.alice.imports = [ home.i3 ]; } ];
    reject-niri-without-system = rejects [ { home-manager.users.alice.imports = [ home.niri ]; } ];
    niri-prerequisites =
      builtins.isString
        (fixture [
          nixos.niri
          {
            home-manager.users.alice.imports = [ home.niri ];
          }
        ]).config.system.build.toplevel.drvPath;
    reject-niri-without-keyring = rejects [
      nixos.niri
      {
        home-manager.users.alice.imports = [ home.niri ];
        services.gnome.gnome-keyring.enable = lib.mkForce false;
      }
    ];
    reject-audio-without-system = rejects [ { home-manager.users.alice.imports = [ home.sound ]; } ];
    reject-personal-link-for-other-user = rejects [
      { home-manager.users.alice.imports = [ home.rinyaresu-ssh ]; }
    ];
    reject-bootstrap-without-agent = rejects [
      { home-manager.users.alice.imports = [ home.pi-bootstrap ]; }
    ];
    reject-bootstrap-without-known-host = rejects [
      nixos.ssh-agent
      {
        home-manager.users.alice.imports = [ home.pi-bootstrap ];
      }
    ];
    bootstrap-prerequisites =
      builtins.isString
        (fixture [
          nixos.pi-bootstrap
          {
            home-manager.users.alice.imports = [ home.pi-bootstrap ];
          }
        ]).config.system.build.toplevel.drvPath;
    desktop-home = builtins.attrNames desktop.home-manager.users == [ "rinyaresu" ];
    lab-home = builtins.attrNames lab.home-manager.users == [ "rinyaresu" ];
    desktop-personal-secret =
      desktop.sops.secrets.rinyaresu-ssh-key.owner == "rinyaresu"
      && desktop.sops.secrets.rinyaresu-ssh-key.mode == "0600"
      && builtins.elem "sops-install-secrets.service" desktop.systemd.services.home-manager-rinyaresu.requires;
    lab-no-personal-state =
      lab.sops.secrets == { }
      && !(lab.home-manager.users.rinyaresu.systemd.user.services ? pi-config-restore);
    lab-isolation =
      !lab.virtualisation.mountHostNixStore
      && lab.virtualisation.useNixStoreImage
      && lab.virtualisation.writableStore
      && !lab.virtualisation.writableStoreUseTmpfs
      && lab.virtualisation.sharedDirectories == { }
      && lab.virtualisation.restrictNetwork
      && lab.virtualisation.qemu.networkingOptions == [ "-nic none" ];
    ordis-no-home-manager = !(ordis ? home-manager);
    ordis-no-personal-account = !(ordis.users.users ? rinyaresu);
    ordis-no-personal-services =
      !(ordis ? sops)
      && !ordis.programs.fish.enable
      && !ordis.virtualisation.docker.enable
      && !ordis.virtualisation.libvirtd.enable
      && !ordis.services.xserver.enable
      && !ordis.programs.niri.enable;
    ordis-access =
      ordis.services.openssh.enable
      && !ordis.services.openssh.openFirewall
      && ordis.networking.networkmanager.enable
      && ordis.security.sudo.wheelNeedsPassword
      && ordis.users.users.ordis.uid == 1000;
    tailscale-only-ordis =
      ordis.services.tailscale.enable
      && !desktop.services.tailscale.enable
      && !lab.services.tailscale.enable;
    ordis-private-ssh =
      ordis.networking.firewall.enable
      && ordis.networking.firewall.allowedTCPPorts == [ ]
      && ordis.networking.firewall.allowedUDPPorts == [ ]
      && ordis.networking.firewall.interfaces.tailscale0.allowedTCPPorts == [ 22 ]
      && !(builtins.elem "tailscale0" ordis.networking.firewall.trustedInterfaces)
      && lib.hasInfix "-s 192.168.1.0/24 -d 192.168.1.196/32" ordis.networking.firewall.extraCommands;
    ordis-pihole-tailscale-composition =
      ordis.services.pihole-ftl.enable
      && ordis.services.tailscale.enable
      && ordis.services.pihole-ftl.settings.dns.interface == "eno1"
      && ordis.services.pihole-web.ports == "127.0.0.1:8080"
      &&
        lib.count (line: lib.hasInfix "--dport 53" line) (
          lib.splitString "\n" ordis.networking.firewall.extraCommands
        ) == 2
      &&
        lib.count (line: lib.hasInfix "--dport 22" line) (
          lib.splitString "\n" ordis.networking.firewall.extraCommands
        ) == 1;
    tailscale-no-dns-or-routing =
      ordis.services.tailscale.authKeyFile == null
      && !ordis.services.tailscale.openFirewall
      && ordis.services.tailscale.useRoutingFeatures == "none"
      && ordis.services.tailscale.extraSetFlags == [ ]
      && builtins.length ordis.services.tailscale.extraDaemonFlags == 1
      && lib.hasPrefix "--config=" (builtins.head ordis.services.tailscale.extraDaemonFlags);
    ordis-storage-and-boot =
      ordis.fileSystems."/".device == "/dev/disk/by-uuid/4398e4d6-b2d0-4810-b45a-2f5331b44c3a"
      && ordis.fileSystems."/home".options == [ "subvol=home" ]
      && builtins.elem "subvol=nix" ordis.fileSystems."/nix".options
      && ordis.boot.loader.systemd-boot.enable
      && !ordis.boot.loader.limine.enable
      && !ordis.zramSwap.enable
      && builtins.length ordis.swapDevices == 1
      &&
        (builtins.head ordis.swapDevices).device == "/dev/disk/by-uuid/d00e945f-6814-4b1d-b11a-3f1af3e9e99e"
      && ordis.fileSystems."/boot".device == "/dev/disk/by-uuid/AB9D-1160";
    preserved-state-versions = builtins.all (c: c.system.stateVersion == "26.05") [
      desktop
      lab
      ordis
    ];
    no-legacy-groups =
      builtins.all (name: !(builtins.hasAttr name nixos) && !(builtins.hasAttr name home))
        [
          "base"
          "gui"
          "development"
        ];
    real-host-assertions = builtins.all (c: builtins.all (a: a.assertion) c.assertions) [
      desktop
      lab
      ordis
    ];
  };
  failures = builtins.attrNames (lib.filterAttrs (_: pass: !pass) results);
in
{
  perSystem = { pkgs, ... }: {
    checks.architecture =
      assert lib.assertMsg (
        failures == [ ]
      ) "Architecture checks failed: ${lib.concatStringsSep ", " failures}";
      pkgs.writeText "architecture-checks.json" (builtins.toJSON results);
  };
}
