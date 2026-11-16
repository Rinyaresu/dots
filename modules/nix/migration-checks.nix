{ config, lib, ... }:
let
  host = config.flake.nixosConfigurations.desktop;
  desktop = host.config;
  home = desktop.home-manager.users.rinyaresu;
  pkgs = host.pkgs;
  has = package: builtins.elem (toString package) (map toString home.home.packages);
  results = {
    boot-policy = desktop.boot.loader.limine.enable && !desktop.boot.loader.limine.secureBoot.enable;
    unencrypted = desktop.boot.initrd.luks.devices == { };
    storage =
      builtins.all
        (
          mount:
          desktop.fileSystems.${mount}.fsType == "btrfs"
          && builtins.elem "compress=zstd" desktop.fileSystems.${mount}.options
        )
        [
          "/"
          "/home"
          "/nix"
        ]
      && builtins.elem "subvol=@" desktop.fileSystems."/".options
      && builtins.elem "subvol=@home" desktop.fileSystems."/home".options
      && builtins.elem "subvol=@nix" desktop.fileSystems."/nix".options;
    no-hibernation =
      !desktop.systemd.sleep.settings.Sleep.AllowHibernation
      && !desktop.systemd.sleep.settings.Sleep.AllowHybridSleep
      && !desktop.systemd.sleep.settings.Sleep.AllowSuspendThenHibernate;
    zram =
      desktop.zramSwap.enable
      && desktop.zramSwap.memoryPercent == 100
      && desktop.zramSwap.algorithm == "zstd"
      && desktop.swapDevices == [ ];
    local-password = desktop.security.sudo.wheelNeedsPassword && desktop.users.mutableUsers;
    identity =
      desktop.networking.hostName == "desktop"
      && desktop.users.users.rinyaresu.isNormalUser
      && home.home.username == "rinyaresu";
    network = desktop.networking.networkmanager.enable && desktop.networking.nameservers == [ ];
    manual-session = !desktop.services.displayManager.enable;
    fish = desktop.users.users.rinyaresu.shell == pkgs.fish && home.programs.fish.enable;
    regional =
      desktop.i18n.defaultLocale == "en_US.UTF-8"
      && desktop.time.timeZone == "America/Sao_Paulo"
      && builtins.all (key: desktop.i18n.extraLocaleSettings.${key} == "pt_BR.UTF-8") [
        "LC_TIME"
        "LC_NUMERIC"
        "LC_MONETARY"
        "LC_ADDRESS"
        "LC_TELEPHONE"
      ];
    docker =
      desktop.virtualisation.docker.enable
      && desktop.virtualisation.docker.enableOnBoot
      && !(builtins.elem "docker" desktop.users.users.rinyaresu.extraGroups)
      && desktop.virtualisation.docker.daemon.settings.ip == "127.0.0.1"
      &&
        desktop.virtualisation.docker.daemon.settings.default-network-opts.bridge."com.docker.network.bridge.host_binding_ipv4"
        == "127.0.0.1";
    no-native-postgres = !desktop.services.postgresql.enable;
    virtualisation =
      desktop.virtualisation.libvirtd.enable
      && !desktop.virtualisation.libvirtd.qemu.runAsRoot
      && desktop.virtualisation.libvirtd.onBoot == "ignore"
      && !(builtins.elem "libvirtd" desktop.users.users.rinyaresu.extraGroups);
    manual-updates = !desktop.system.autoUpgrade.enable;
    audio =
      desktop.services.pipewire.enable
      && desktop.services.pipewire.alsa.enable
      && desktop.services.pipewire.pulse.enable
      && desktop.services.pipewire.wireplumber.enable;
    firefox =
      has pkgs.firefox
      && desktop.xdg.mime.defaultApplications."x-scheme-handler/https" == "firefox.desktop";
    wireguard-tools-only =
      builtins.elem pkgs.wireguard-tools desktop.environment.systemPackages
      && desktop.networking.wg-quick.interfaces == { };
    chrome = has pkgs.google-chrome;
    neovim =
      home.programs.neovim.enable
      && !home.programs.neovim.withRuby
      &&
        map toString home.programs.neovim.extraPackages == map toString [
          pkgs.bash-language-server
          pkgs.nixd
          pkgs.typescript-language-server
        ];
    default-kernel = desktop.boot.kernelPackages.kernel.version == pkgs.linuxPackages.kernel.version;
    usb = builtins.elem "usbcore.autosuspend=-1" desktop.boot.kernelParams;
    bluetooth = desktop.hardware.bluetooth.enable && desktop.hardware.bluetooth.powerOnBoot;
    no-gaming = !desktop.programs.steam.enable;
    external-tools = desktop.programs.nix-ld.enable && desktop.services.envfs.enable;
    no-broad-session-killing = !desktop.systemd.oomd.enableUserSlices;
    no-windows-mount =
      builtins.attrNames desktop.fileSystems == [
        "/"
        "/bin"
        "/boot"
        "/home"
        "/nix"
        "/usr/bin"
      ];
    removable =
      desktop.services.gvfs.enable
      && !home.dconf.settings."org/gnome/desktop/media-handling".automount
      && !home.dconf.settings."org/gnome/desktop/media-handling".automount-open;
    apps =
      builtins.all has [
        pkgs.obsidian
        pkgs.anki
        pkgs.dbeaver-bin
        pkgs.bitwarden-desktop
      ]
      && lib.count (package: (package.pname or "") == "vscode") home.home.packages == 1;
    no-printer = !desktop.services.printing.enable && !desktop.hardware.sane.enable;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
{
  perSystem = { pkgs, ... }: {
    checks.migration-options =
      assert lib.assertMsg (
        failures == [ ]
      ) "Migration option checks failed: ${lib.concatStringsSep ", " failures}";
      pkgs.writeText "migration-options.json" (builtins.toJSON results);
  };
}
