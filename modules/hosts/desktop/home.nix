{ config, ... }:
let
  home = config.flake.modules.homeManager;
in
{
  flake.modules.nixos.host-desktop = {
    imports = [ config.flake.modules.nixos.home-manager ];
    home-manager.users.rinyaresu = {
      home.stateVersion = "26.05";
      imports = [
        home.rinyaresu
        home.fish
        home.herdr
        home.neovim
        home.pi
        home.providers
        home.chrome
        home.discord
        home.files
        home.firefox
        home.ghostty
        home.obs
        home.spotify
        home.stremio
        home.polkit
        home.i3
        home.niri
        home.sound
        home.rinyaresu-ssh
        home.pi-bootstrap
      ];
    };
  };
}
