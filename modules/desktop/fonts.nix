{
  flake.modules.nixos.gui = { pkgs, ... }: {
    fonts.packages = [ pkgs.nerd-fonts.iosevka ];
  };
}
