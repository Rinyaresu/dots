{
  flake.modules.nixos.tailscale = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.tailscale";
    services.tailscale = {
      enable = true;
      # Outbound NAT traversal / DERP suffice; no public inbound port is required.
      openFirewall = false;
      useRoutingFeatures = "none";
      disableTaildrop = true;
      # The pinned daemon supports alpha0 configuration, applied BEFORE network
      # connectivity. A later tailscaled-set oneshot could briefly restore DNS
      # or install ts-input's all-ports ACCEPT from drifted persistent prefs.
      # No AuthKey here: interactive login, identity in /var/lib/tailscale.
      extraDaemonFlags = [
        "--config=${
          pkgs.writeText "tailscale-policy.json" (
            builtins.toJSON {
              version = "alpha0";
              Locked = true;
              acceptDNS = false;
              acceptRoutes = false;
              exitNode = "";
              AdvertiseRoutes = [ ];
              AdvertiseExitNode = false;
              NetfilterMode = "off";
              RunSSHServer = false;
              RunWebClient = false;
              RemoteConfig = false;
              AutoUpdate = {
                Check = false;
                Apply = false;
              };
            }
          )
        }"
      ];
    };
  };
}
