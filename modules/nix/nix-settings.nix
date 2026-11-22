{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nix-settings;
in
{
  flake.modules.nixos.nix-settings = {
    key = "${__curPos.file}#nixos.nix-settings";
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    system.autoUpgrade.enable = false;
  };

  flake.modules.nixos.base = {
    imports = [ config.flake.modules.nixos.common ];
  };
  flake.modules.nixos.common.imports = [ nix-settings ];
}
