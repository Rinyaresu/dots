{
  flake.modules.nixos.base = { pkgs, ... }: {
    programs.fish.enable = true;
    users.users.rinyaresu.shell = pkgs.fish;
  };
  flake.modules.homeManager.base.programs.fish.enable = true;
}
