{ config, ... }:
{
  flake.modules.nixos.polkit.key = "${__curPos.file}#nixos.polkit";
  flake.modules.nixos.polkit.security.polkit.enable = true;
  flake.modules.homeManager.polkit = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.polkit";
    systemd.user.services.polkit-gnome-authentication-agent = {
      Unit = {
        Description = "GNOME Polkit authentication agent";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP";
      };
      Service = {
        ExecCondition = "${pkgs.bash}/bin/bash -c 'test -n \"$DISPLAY\" || test -n \"$WAYLAND_DISPLAY\"'";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  flake.modules.nixos.gui = {
    imports = [ config.flake.modules.nixos.polkit ];
  };
  flake.modules.homeManager.gui = {
    imports = [ config.flake.modules.homeManager.polkit ];
  };
}
