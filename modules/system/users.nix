{
  flake.modules.nixos.base = {
    security.sudo.wheelNeedsPassword = true;
    users.users.rinyaresu = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "wheel" ];
    };
  };

  flake.modules.homeManager.base.home = {
    username = "rinyaresu";
    homeDirectory = "/home/rinyaresu";
  };
}
