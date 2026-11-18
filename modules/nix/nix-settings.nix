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
    nix.gc.automatic = false;
    system.autoUpgrade.enable = false;
  };

  flake.modules.nixos.base = {
    imports = [ config.flake.modules.nixos.common ];
  };
  flake.modules.nixos.common = { config, ... }: {
    imports = [ nix-settings ];
    assertions = [
      {
        assertion = !config.nix.gc.automatic && !(config.systemd.timers ? nix-gc);
        message = "Hosts must keep Nix garbage collection manual.";
      }
    ];
  };
}
