{
  flake.modules.nixos.gui.security.polkit.enable = true;
  flake.modules.homeManager.gui = { pkgs, ... }: {
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
}
