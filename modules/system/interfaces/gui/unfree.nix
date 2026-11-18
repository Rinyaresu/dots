{ config, ... }:
{
  flake.modules.nixos.unfree-desktop = { lib, ... }: {
    key = "${__curPos.file}#nixos.unfree-desktop";
    nixpkgs.config.allowUnfreePredicate =
      package:
      builtins.elem (lib.getName package) [
        "google-chrome"
        "discord"
        "spotify"
        "stremio-linux-shell"
        "obsidian"
        "vscode"
      ];
  };

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.unfree-desktop ];
  };
}
