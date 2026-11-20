{ config, ... }:
let
  pihole = config.flake.modules.nixos.pihole;
in
{
  configurations.nixos.ordis.modules.pihole-local =
    { config, lib, ... }:
    let
      lan = "192.168.1.196";
      name = "pihole.home.arpa";
      source = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
      webPorts = [
        "127.0.0.1:8080"
        "${lan}:8443os"
      ];
      ftl = config.services.pihole-ftl;
    in
    {
      imports = [ pihole ];

      assertions = [
        {
          assertion =
            ftl.enable
            && config.services.pihole-web.enable
            && config.services.pihole-web.ports == lib.concatStringsSep "," webPorts
            && !ftl.openFirewallDNS
            && !ftl.openFirewallWebserver
            && !ftl.openFirewallDHCP;
          message = "Pi-hole must use only its explicit IPv4 ingress rules.";
        }
      ];

      services.pihole-web = {
        hostName = name;
        ports = lib.mkForce webPorts;
      };

      services.pihole-ftl = {
        privacyLevel = lib.mkForce 0;
        settings = {
          dns = {
            interface = "eno1";
            upstreams = lib.mkForce [ "127.0.0.1#5053" ];
            hosts = [ "${lan} ${name}" ];
            # FTL's history database is independent of the dnsmasq text log.
            queryLogging = false;
          };
          database = {
            DBinterval = 60;
            maxDBdays = 7;
          };
          webserver.tls.cert = lib.mkForce "${ftl.stateDirectory}/ordis-tls.pem";
        };
        lists = [
          {
            url = source;
            description = "StevenBlack Unified Hosts";
          }
        ];
        macvendorURL = "file:///dev/null";
      };

      services.dnscrypt-proxy = {
        enable = true;
        upstreamDefaults = false;
        settings = {
          listen_addresses = [ "127.0.0.1:5053" ];
          server_names = [ "cloudflare" ];
          static.cloudflare.stamp = "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmRucy5jbG91ZGZsYXJlLmNvbQovZG5zLXF1ZXJ5";
          dnscrypt_servers = false;
          doh_servers = true;
          ignore_system_dns = true;
          bootstrap_resolvers = [ ];
          netprobe_timeout = 0;
          cache = false;
        };
      };

      # Don't let the proxy module introduce a loopback host resolver on port 53.
      networking.nameservers = lib.mkForce [ ];

      systemd.services = {
        pihole-ftl = {
          wants = lib.mkForce [ "dnscrypt-proxy.service" ];
          after = [ "dnscrypt-proxy.service" ];
          environment = {
            PIHOLE_MANAGED_HOSTS_URL = source;
            PIHOLE_TLS_NAME = name;
            PIHOLE_TLS_PEM = ftl.settings.webserver.tls.cert;
          };
        };
        pihole-ftl-setup = {
          environment.PIHOLE_MANAGED_HOSTS_URL = source;
          serviceConfig.TimeoutStartSec = "5min";
        };
      };
      systemd.timers.pihole-ftl-setup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          RandomizedDelaySec = "10min";
          Persistent = true;
        };
      };

      networking.firewall.extraCommands = ''
        iptables -A nixos-fw -i eno1 -s 192.168.1.0/24 -p udp --dport 53 -j nixos-fw-accept
        iptables -A nixos-fw -i eno1 -s 192.168.1.0/24 -p tcp --dport 53 -j nixos-fw-accept
        iptables -A nixos-fw -i eno1 -s 192.168.1.65/32 -d ${lan}/32 -p tcp --dport 8443 -j nixos-fw-accept
      '';
    };
}
