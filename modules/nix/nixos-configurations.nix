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
        options = {
          modules = lib.mkOption {
            type = lib.types.attrsOf lib.types.deferredModule;
            default = { };
          };
          homeUser = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Native NixOS account for the selected Home Manager modules.";
          };
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mapAttrs (
    host:
    { modules, homeUser }:
    let
      matched = builtins.intersectAttrs modules config.flake.modules.homeManager;
    in
    inputs.nixpkgs.lib.nixosSystem {
      modules =
        lib.attrValues modules
        ++ lib.optionals (matched != { }) (
          if homeUser == null || homeUser == "" then
            throw "configurations.nixos.${host}.homeUser must name a native NixOS account when Home Manager modules match."
          else
            [
              config.flake.modules.nixos.home-manager
              (
                { config, ... }:
                {
                  assertions = [
                    {
                      assertion = config.users.users.${homeUser}.isNormalUser or false;
                      message = "configurations.nixos.${host}.homeUser names '${homeUser}', which is not a normal NixOS account on this host.";
                    }
                  ];
                  home-manager.users.${homeUser}.imports = lib.attrValues matched;
                }
              )
            ]
        );
    }
  ) config.configurations.nixos;
}
