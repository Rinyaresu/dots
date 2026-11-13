{
  flake.modules.nixos.gui = { lib, ... }: {
    nixpkgs.config.allowUnfreePredicate =
      package:
      builtins.elem (lib.getName package) [
        "google-chrome"
        "discord"
        "spotify"
        "stremio-linux-shell"
      ];
  };
}
