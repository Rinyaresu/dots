{
  flake.modules.homeManager.discord = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.discord";
    home.packages = [ pkgs.discord ];
    systemd.user.services.discord = {
      Unit = {
        Description = "Discord graphical session autostart";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP";
      };
      Service = {
        Environment = [ "NIXOS_OZONE_WL=1" ];
        ExecCondition = "${pkgs.bash}/bin/bash -c 'case \"$XDG_SESSION_TYPE\" in x11|wayland) exit 0 ;; *) exit 1 ;; esac'";
        ExecStart = "${pkgs.discord}/bin/Discord";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
