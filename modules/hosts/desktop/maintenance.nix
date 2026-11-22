{
  configurations.nixos.desktop.modules.maintenance = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.efibootmgr ];
    services.smartd.enable = true;
    services.btrfs.autoScrub.enable = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };
  };
}
