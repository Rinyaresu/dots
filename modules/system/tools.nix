{
  flake.modules.nixos.base = { pkgs, ... }: {
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
