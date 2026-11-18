{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  flake.modules.nixos = {
    gui = {
      imports = with nixos; [
        unfree-desktop
        graphics
        fonts
        polkit
        files
        firefox
        bluetooth
        sound
      ];
    };

  };

  flake.modules.homeManager = {
    gui = {
      imports = with homeManager; [
        chrome
        discord
        files
        firefox
        ghostty
        obs
        spotify
        stremio
        polkit
        sound
      ];
    };

    desktop-personal = {
      imports = with homeManager; [
        obsidian
        anki
        dbeaver
        code
        bitwarden
      ];
    };
  };
}
