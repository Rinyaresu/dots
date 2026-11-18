{ config, ... }:
{
  flake.modules.nixos.fish.key = "${__curPos.file}#nixos.fish";
  flake.modules.nixos.fish.programs.fish.enable = true;
  flake.modules.homeManager.fish.key = "${__curPos.file}#homeManager.fish";
  flake.modules.homeManager.fish.programs.fish.enable = true;

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.fish ];
  };
}
