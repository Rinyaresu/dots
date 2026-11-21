{ interface, address }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ip = lib.getExe' pkgs.iproute2 "ip";
  unit = "pihole-link-local";
  addressArgs = "${address}/128 dev ${interface}";
  addAddress = "${ip} -6 address replace ${addressArgs} noprefixroute";
  device = "sys-subsystem-net-devices-${interface}.device";
in
{
  assertions = [
    {
      assertion = config.networking.firewall.enable && config.networking.firewall.backend == "iptables";
      message = "Pi-hole link-local DNS requires the NixOS iptables firewall backend.";
    }
  ];

  systemd.services.${unit} = {
    description = "Dedicated Pi-hole IPv6 link-local address on ${interface}";
    wantedBy = [ "multi-user.target" ];
    bindsTo = [ device ];
    after = [ device ] ++ lib.optional config.networking.networkmanager.enable "NetworkManager.service";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = addAddress;
      ExecReload = addAddress;
      ExecStop = "-${ip} -6 address del ${addressArgs}";
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      NoNewPrivileges = true;
    };
  };

  # Restore only the alias after activation/reapply, without owning the profile.
  networking.networkmanager.dispatcherScripts = lib.mkIf config.networking.networkmanager.enable [
    {
      source = lib.getExe (
        pkgs.writeShellApplication {
          name = "pihole-link-local-dispatcher";
          text = ''
            [ "$1" = "${interface}" ] || exit 0
            case "$2" in
              up|reapply) exec ${lib.getExe' pkgs.systemd "systemctl"} --no-block reload-or-restart ${unit}.service ;;
            esac
          '';
        }
      );
    }
  ];

  # The destination has link scope. Do not assume clients pick a link-local source.
  networking.firewall.extraCommands = ''
    ip6tables -A nixos-fw -i ${interface} -d ${address}/128 -p udp --dport 53 -j nixos-fw-accept
    ip6tables -A nixos-fw -i ${interface} -d ${address}/128 -p tcp --dport 53 -j nixos-fw-accept
  '';
}
