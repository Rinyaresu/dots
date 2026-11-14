{ inputs, ... }:
{
  flake.modules.nixos.nix-settings = {
    key = "${__curPos.file}#nixos.nix-settings";
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
    nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    nix.gc.automatic = false;
    system.autoUpgrade.enable = false;
  };
}
