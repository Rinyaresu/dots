{
  description = "Kaique's multi-host NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    import-tree.url = "github:vic/import-tree";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    pi.url = "github:earendil-works/pi/v1.5.0";
    pi.inputs.nixpkgs.follows = "nixpkgs";
    pi.inputs.nixpkgs-darwin-x64.follows = "nixpkgs";
    herdr.url = "github:herdrdev/herdr/2ecf19a92fc3a7fff75b6ce3655ef04f4625ec01";
    herdr.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { pkgs, ... }: { formatter = pkgs.nixfmt; };
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
      ];
    };
}
