{ config, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  flake.modules.nixos = {
    base = {
      imports = with nixos; [
        rinyaresu
        tools
        toolchain
      ];
    };

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

    desktop-personal = {
      imports = with nixos; [
        rinyaresu-ssh
        pi-bootstrap
      ];
    };
  };

  flake.modules.homeManager = {
    base = {
      imports = with homeManager; [
        rinyaresu
        fish
        herdr
        neovim
        pi
        providers
      ];
    };

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
        herdr-tree
        obsidian
        anki
        dbeaver
        code
        bitwarden
        rinyaresu-ssh
        pi-bootstrap
      ];
    };
  };
}
