{
  configurations.nixos.desktop.modules.maintenance = {
    nix.gc = {
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };
  };
}
