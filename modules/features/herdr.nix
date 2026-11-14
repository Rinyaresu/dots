{ config, inputs, ... }:
{
  flake.modules.homeManager.herdr = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.herdr";
    imports = [ config.flake.modules.homeManager.fish ];
    home.packages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr ];
    xdg.configFile."herdr/config.toml".text = ''
      [terminal]
      default_shell = "${pkgs.fish}/bin/fish"

      [update]
      version_check = false
      manifest_check = false
    '';
  };
}
