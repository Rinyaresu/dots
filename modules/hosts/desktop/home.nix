{
  configurations.nixos.desktop.modules.home = {
    home-manager.users.rinyaresu = { lib, ... }: {
      home.stateVersion = "26.05";
      xdg.configFile."niri/config.kdl".text = lib.mkAfter ''
        output "DP-1" {
            mode "2560x1440@164.958"
            scale 1
            position x=0 y=0
            focus-at-startup
        }
        output "HDMI-A-2" {
            mode "1920x1080@143.981"
            scale 1
            transform "90"
            position x=2560 y=0
        }
      '';
    };
  };
}
