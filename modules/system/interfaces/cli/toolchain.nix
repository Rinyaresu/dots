{
  flake.modules.nixos.base = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.toolchain";
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
        libyaml
        readline
        libffi
        gmp
        libxcrypt
        libuuid
      ];
    };
    services.envfs.enable = true;
    environment.systemPackages = with pkgs; [
      gcc
      gnumake
      pkg-config
      cmake
      openssl
      sqlite
      libyaml
    ];
  };

  flake.modules.homeManager.desktop-personal = { pkgs, ... }: {
    home.packages = [ pkgs.python3 ];
  };

  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        fish
        gcc
        gnumake
        pkg-config
      ];
      buildInputs = with pkgs; [
        openssl
        libyaml
        zlib
        libpq
        libffi
      ];
    };
  };
}
