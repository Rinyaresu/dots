{
  config,
  inputs,
  lib,
  ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.modules = lib.mkOption {
          type = lib.types.attrsOf lib.types.deferredModule;
          default = { };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    _:
    { modules, ... }:
    let
      matchingHome = lib.filterAttrs (
        name: _: builtins.hasAttr name modules
      ) config.flake.modules.homeManager;
    in
    inputs.nixpkgs.lib.nixosSystem {
      modules =
        lib.attrValues modules
        ++ lib.optionals (matchingHome != { }) [
          inputs.home-manager.nixosModules.home-manager
          { home-manager.users.rinyaresu.imports = lib.attrValues matchingHome; }
        ];
    }
  ) config.configurations.nixos;
}
