{ config, ... }:
{
  configurations.nixos.ordis.modules.pihole-local = { config, pkgs, ... }: {
    imports = [ config.flake.modules.nixos.pihole ];

    assertions = [
      {
        assertion =
          config.services.pihole-web.ports == "127.0.0.1:8080"
          && !config.services.pihole-ftl.openFirewallDNS
          && !config.services.pihole-ftl.openFirewallWebserver
          && !config.services.pihole-ftl.openFirewallDHCP;
        message = "Pi-hole administration must stay on loopback and must not open the global firewall.";
      }
    ];

    services.pihole-ftl = {
      settings.dns.interface = "eno1";
      # Immutable list snapshot; no boot-time dependency on a public list server.
      lists = [
        {
          url = "file://${
            pkgs.fetchurl {
              url = "https://raw.githubusercontent.com/StevenBlack/hosts/35c74714ad86b36806b3f40f3c36abf8b2063cb5/hosts";
              hash = "sha256-+S1l6PYEwO/xaE7U7kewVBbu7fayTcrK/wdD9/Ix6VY=";
            }
          }";
          description = "StevenBlack unified hosts snapshot (35c74714)";
        }
      ];
      # MAC vendor enrichment is unnecessary; avoid an external boot-time download.
      macvendorURL = "file:///dev/null";
    };

    # IPv4 LAN only. Do not accidentally admit the globally addressed IPv6 host.
    # The web UI stays on loopback; DHCP/NTP remain on the existing infrastructure.
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -i eno1 -s 192.168.1.0/24 -p udp --dport 53 -j nixos-fw-accept
      iptables -A nixos-fw -i eno1 -s 192.168.1.0/24 -p tcp --dport 53 -j nixos-fw-accept
    '';
  };
}
