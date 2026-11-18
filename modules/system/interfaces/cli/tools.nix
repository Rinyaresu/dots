{ config, ... }:
{
  flake.modules.nixos.tools = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.tools";
    environment.systemPackages = with pkgs; [
      btop
      ripgrep
      fd
      fzf
      jq
      file
      zip
      unzip
      lsof
      dnsutils
      pciutils
      usbutils
      gh
    ];
  };

  flake.modules.nixos.base = {
    imports = [ config.flake.modules.nixos.tools ];
  };
}
