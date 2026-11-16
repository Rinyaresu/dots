{
  flake.modules.nixos.host-desktop = {
    nix.gc = {
      dates = "weekly";
      options = "--delete-older-than 30d";
      persistent = true;
    };
  };
}
