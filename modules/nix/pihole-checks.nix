{ config, lib, ... }:
let
  hosts = config.flake.nixosConfigurations;
  ordis = hosts.ordis.config;
  results = {
    selected-only-on-ordis =
      ordis.services.pihole-ftl.enable
      && !hosts.desktop.config.services.pihole-ftl.enable
      && !hosts.lab.config.services.pihole-ftl.enable;
    no-global-openings =
      !ordis.services.pihole-ftl.openFirewallDNS
      && !ordis.services.pihole-ftl.openFirewallWebserver
      && !ordis.services.pihole-ftl.openFirewallDHCP;
    local-admin = ordis.services.pihole-web.ports == "127.0.0.1:8080";
    no-dhcp-or-ntp =
      !ordis.services.pihole-ftl.settings.dhcp.active
      && !ordis.services.pihole-ftl.settings.ntp.ipv4.active
      && !ordis.services.pihole-ftl.settings.ntp.ipv6.active
      && !ordis.services.pihole-ftl.settings.ntp.sync.active;
    external-hash =
      ordis.systemd.services.pihole-ftl.serviceConfig.LoadCredential
      == [ "admin-hash:/var/lib/pihole-secrets/admin-hash" ];
    read-only-config = ordis.services.pihole-ftl.settings.misc.readOnly;
    minimal-capabilities =
      ordis.systemd.services.pihole-ftl.serviceConfig.AmbientCapabilities == [ "CAP_NET_BIND_SERVICE" ];
  };
in
{
  perSystem = { pkgs, ... }: {
    checks.pihole-policy =
      assert lib.all (x: x) (builtins.attrValues results);
      pkgs.writeText "pihole-policy.json" (builtins.toJSON results);
    checks.pihole = import ../../checks/pihole.nix {
      inherit pkgs ordis;
      piholeModule = config.flake.modules.nixos.pihole;
    };
  };
}
