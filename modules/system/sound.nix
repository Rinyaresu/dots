{
  flake.modules.nixos.sound = {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
  flake.modules.homeManager.sound = { pkgs, ... }: {
    home.packages = [ pkgs.pavucontrol ];
  };
}
