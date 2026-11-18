{ config, ... }:
{
  flake.modules.nixos.sound = {
    key = "${__curPos.file}#nixos.sound";
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
  flake.modules.homeManager.sound = { osConfig, pkgs, ... }: {
    key = "${__curPos.file}#homeManager.sound";
    assertions = [
      {
        assertion = osConfig.services.pipewire.enable && osConfig.services.pipewire.pulse.enable;
        message = "The audio controls require the host PipeWire PulseAudio service.";
      }
    ];
    home.packages = [ pkgs.pavucontrol ];
  };

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.sound ];
  };
  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.sound ];
  };
}
