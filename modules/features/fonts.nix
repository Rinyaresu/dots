{
  flake.modules.nixos.fonts = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.fonts";
    fonts.packages = [ pkgs.nerd-fonts.iosevka ];
  };
}
