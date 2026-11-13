{ inputs, ... }:
{
  flake.modules.homeManager.development = { pkgs, ... }: {
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
