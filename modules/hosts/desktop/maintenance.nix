{
  configurations.nixos.desktop.modules.maintenance = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.efibootmgr ];
    nix.gc = {
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };
  };
}
