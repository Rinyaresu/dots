{ inputs, ... }:
{
  flake.modules.nixos.home-manager = {
    key = "${__curPos.file}#nixos.home-manager";
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [
        (
          {
            config,
            name,
            osConfig,
            ...
          }:
          {
            assertions = [
              {
                assertion =
                  config.home.username == osConfig.users.users.${name}.name
                  && config.home.homeDirectory == osConfig.users.users.${name}.home;
                message = "Home Manager identity must match its NixOS account ${name}.";
              }
            ];
          }
        )
      ];
    };
  };
}
