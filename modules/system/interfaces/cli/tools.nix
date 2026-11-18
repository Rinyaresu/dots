{
  flake.modules.nixos.base = { pkgs, ... }: {
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
}
