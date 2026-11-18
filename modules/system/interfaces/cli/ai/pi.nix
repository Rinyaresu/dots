{ config, inputs, ... }:
{
  flake.modules.homeManager.pi = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.pi";
    home.packages = [
      (inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        nodejs_22 = pkgs.nodejs_24;
        importNpmLock = pkgs.importNpmLock // {
          importNpmLock =
            args:
            pkgs.importNpmLock (
              args
              // pkgs.lib.optionalAttrs (args ? packageSourceOverrides) {
                packageSourceOverrides = args.packageSourceOverrides // {
                  "node_modules/@earendil-works/pi-schema" = pkgs.fetchurl {
                    url = "https://registry.npmjs.org/@earendil-works/pi-schema/-/pi-schema-1.5.0.tgz";
                    hash = "sha512-RW0MbT2tR65OY6xMsgB/yVBb7m/RTNwA+9hurSN1vVXfHZRVmVnXbruBPrx/PzbrQnW5yLVlMRWxErGDQtF1Hg==";
                  };
                };
              }
            );
        };
      })
    ];
    home.sessionVariables.PI_NODE_BIN = "${pkgs.nodejs_24}/bin/node";
  };

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.pi ];
  };
}
