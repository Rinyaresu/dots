{
  inputs,
  nixos,
  home,
  extraModules ? [ ],
}:
inputs.nixpkgs.lib.nixosSystem {
  modules = [
    nixos.home-manager
    nixos.unfree-desktop
    nixos.niri
    nixos.i3
    nixos.fonts
    nixos.sound
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "26.05";
      boot.loader.grub.enable = false;
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };
      users.users.alice = {
        isNormalUser = true;
        home = "/srv/alice";
      };
      home-manager.users.alice = {
        home.stateVersion = "26.05";
        imports = [
          home.niri
          home.i3
          home.discord
        ];
      };
    }
  ]
  ++ extraModules;
}
