{
  pkgs,
  piholeModule,
  ordis,
}:
pkgs.testers.runNixOSTest {
  name = "pihole-network";
  defaults = {
    virtualisation.restrictNetwork = true;
    services.timesyncd.enable = false;
  };
  nodes = {
    server = { lib, ... }: {
      imports = [ piholeModule ];
      virtualisation.memorySize = 1024;
      # gravity.sh insists on resolving these even with exclusively file:// lists.
      # Satisfy only this preflight locally; actual DNS answers come from upstream.
      networking.hosts."192.0.2.1" = [
        "raw.githubusercontent.com"
        "github.com"
      ];
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.196";
          prefixLength = 24;
        }
      ];
      virtualisation.vlans = [
        1
        2
      ];
      networking.firewall.extraCommands =
        builtins.replaceStrings [ "eno1" ] [ "eth1" ]
          ordis.networking.firewall.extraCommands;
      services.pihole-ftl = {
        settings.dns = {
          inherit (ordis.services.pihole-ftl.settings.dns) hosts queryLogging;
          interface = "eth1";
          upstreams = lib.mkForce [ "192.168.1.50#5353" ];
        };
        inherit (ordis.services.pihole-ftl) privacyLevel;
        settings = {
          inherit (ordis.services.pihole-ftl.settings) database;
          webserver.tls.cert = lib.mkForce "/var/lib/pihole/ordis-tls.pem";
        };
        macvendorURL = "file:///dev/null";
        lists = [
          {
            url = "file://${pkgs.writeText "hosts" "0.0.0.0 ads.fixture.example.com\n"}";
            description = "Deterministic integration fixture";
          }
        ];
      };
      services.pihole-web = {
        inherit (ordis.services.pihole-web) hostName;
        ports = lib.mkForce [ ordis.services.pihole-web.ports ];
      };
      systemd.services.pihole-ftl.environment = {
        inherit (ordis.systemd.services.pihole-ftl.environment) PIHOLE_TLS_NAME PIHOLE_TLS_PEM;
      };
      environment.systemPackages = [
        pkgs.openssl
        pkgs.jq
        pkgs.dig
        pkgs.sqlite
        pkgs.python3
        pkgs.curl
      ];
    };
    client = { lib, ... }: {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.65";
          prefixLength = 24;
        }
      ];
      environment.systemPackages = [
        pkgs.dig
        pkgs.curl
      ];
    };
    outside = { ... }: {
      virtualisation.vlans = [ 2 ];
      environment.systemPackages = [
        pkgs.dig
        pkgs.curl
      ];
    };
    upstream = { lib, ... }: {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.50";
          prefixLength = 24;
        }
      ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
      networking.firewall.allowedTCPPorts = [
        5353
        8888
      ];
      systemd.services.hosts-fixture = {
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8888 --bind 192.168.1.50 --directory /run/hosts-fixture";
      };
      services.dnsmasq = {
        enable = true;
        settings = {
          port = 5353;
          no-resolv = true;
          no-hosts = true;
          log-queries = true;
          address = [
            "/allowed.fixture.example.com/203.0.113.42"
            "/allowed.fixture.example.com/2001:db8::42"
            "/ads.fixture.example.com/203.0.113.66"
            "/persist.fixture.example.com/203.0.113.77"
          ];
        };
      };
    };
  };
  testScript = ''
    start_all()
    upstream.wait_for_unit("dnsmasq.service")
    client.wait_for_unit("network.target")
    server.wait_for_unit("multi-user.target")

    with subtest("missing credential fails closed before setup mutates the database"):
        server.fail("systemctl is-active --quiet pihole-ftl.service")
        server.fail("systemctl is-active --quiet pihole-ftl-setup.service")
        server.fail("test -e /var/lib/pihole/gravity.db")
        server.fail("curl --fail --max-time 2 http://127.0.0.1:8080/api/auth")

    with subtest("malformed credential rejects startup before setup mutates the database"):
        server.succeed("install -d -m 700 /var/lib/pihole-secrets; printf '%s' '$BALLOON-SHA256$v=1$s=1024,t=32$A$A' > /var/lib/pihole-secrets/admin-hash; chmod 600 /var/lib/pihole-secrets/admin-hash; systemctl reset-failed pihole-ftl")
        server.fail("systemctl start pihole-ftl")
        server.wait_until_succeeds("systemctl is-failed --quiet pihole-ftl", timeout=30)
        server.fail("systemctl is-active --quiet pihole-ftl-setup.service")
        server.fail("test -e /var/lib/pihole/gravity.db")
        server.fail("curl --fail --max-time 2 http://127.0.0.1:8080/api/auth")
        server.succeed("systemctl stop pihole-ftl-setup pihole-ftl; rm /var/lib/pihole-secrets/admin-hash")

    # Random test-only password exists in VM RAM, never in a derivation or argv.
    server.succeed("python3 ${./pihole-provision.py}")

    with subtest("unavailable loopback API prevents setup even with a valid credential"):
        drop_in = "/run/systemd/system/pihole-ftl.service.d/90-test-api-unavailable.conf"
        server.succeed(f"install -d $(dirname {drop_in}); printf '%s\\n' '[Service]' 'Environment=FTLCONF_webserver_port=127.0.0.1:8081' 'Restart=no' > {drop_in}; systemctl daemon-reload; systemctl reset-failed pihole-ftl")
        server.fail("timeout 45s systemctl start pihole-ftl-setup.service")
        server.succeed("test $(systemctl show -p Result --value pihole-ftl) = exit-code")
        server.succeed("journalctl -b -u pihole-ftl --grep='^FTL loopback API did not become ready' -q --no-pager -o cat | grep -q '^FTL loopback API did not become ready'")
        server.succeed("test $(systemctl show -p ExecMainStartTimestampMonotonic --value pihole-ftl-setup) = 0")
        server.fail("test -e /var/lib/pihole/gravity.db")
        server.succeed(f"rm {drop_in}; systemctl daemon-reload")

    server.succeed("systemctl reset-failed; systemctl restart pihole-ftl")
    server.wait_for_unit("pihole-ftl.service")
    server.succeed("python3 ${./pihole-argv.py} ${ordis.services.pihole-ftl.piholePackage}/share/pihole/advanced/Scripts/api.sh")
    server.wait_until_succeeds("test -s /var/lib/pihole/gravity.db")

    def dns(name, kind="A", tcp=False, expected="203.0.113.42"):
        command = f"dig @192.168.1.196 {name} {kind} +short +time=2 +tries=1 " + ("+tcp" if tcp else "")
        answer = client.wait_until_succeeds(
            f"answer=$({command}); test \"$answer\" = '{expected}' && printf '%s' \"$answer\"",
            timeout=30,
        ).strip()
        assert answer == expected, (command, answer, expected)
        print(f"DNS EVIDENCE: {command} => {answer}")

    def operational():
        try:
            for tcp in [False, True]:
                dns("allowed.fixture.example.com", tcp=tcp)
                dns("allowed.fixture.example.com", "AAAA", tcp, "2001:db8::42")
                dns("ads.fixture.example.com", tcp=tcp, expected="0.0.0.0")
                dns("ads.fixture.example.com", "AAAA", tcp, "::")
        except Exception:
            print(server.execute("cat /var/log/pihole/FTL.log; tail -80 /var/log/pihole/pihole.log; systemctl status pihole-ftl pihole-ftl-setup --no-pager"))
            raise

    with subtest("real UDP/TCP resolution, upstream and NULL blocking"):
        print(client.execute("dig @192.168.1.50 -p 5353 allowed.fixture.example.com +time=2 +tries=1"))
        print(client.succeed("dig @192.168.1.196 allowed.fixture.example.com +time=2 +tries=1"))
        operational()
        upstream.succeed("journalctl -u dnsmasq | grep allowed.fixture.example.com")
        server.succeed("grep '192.168.1.50#5353' /etc/pihole/pihole.toml")
        server.succeed("sqlite3 /var/lib/pihole/gravity.db 'select domain from gravity' | grep -Fx ads.fixture.example.com")

    with subtest("web authentication and loopback restriction"):
        server.succeed("curl -fsSL http://127.0.0.1:8080/ | grep -i '<html'")
        server.succeed("test $(curl -s -o /run/unauth.json -w '%{http_code}' http://127.0.0.1:8080/api/stats/summary) = 401")
        server.succeed("test $(curl -s -o /run/badauth.json -w '%{http_code}' -H 'Content-Type: application/json' -d '{\"password\":\"wrong\"}' http://127.0.0.1:8080/api/auth) = 401")
        # Keep the session SID out of process argv and driver commands/logs.
        server.succeed("umask 077; curl -fsS -H 'Content-Type: application/json' --data-binary @/run/test-auth.json http://127.0.0.1:8080/api/auth > /run/session.json")
        server.succeed("umask 077; python3 - <<'PY'\nimport json\nwith open('/run/session.json') as f: session = json.load(f)['session']\nassert session['valid'] is True\nwith open('/run/session-header', 'w') as f: f.write('sid: ' + session['sid'] + '\\n')\nPY")
        server.succeed("curl -fsS -H @/run/session-header http://127.0.0.1:8080/api/stats/summary > /run/summary.json")
        client.fail("curl --fail --connect-timeout 2 http://192.168.1.196:8080/")
        server.succeed("ss -ltn | grep -F '127.0.0.1:8080'")
        server.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):8080'")
        server.fail("ss -lun | grep -E ':(67|123) '")
        server.succeed("test $(stat -c %a /var/lib/pihole-secrets/admin-hash) = 600")
        server.succeed("test $(stat -c %a /var/lib/pihole) = 700")
        server.succeed("test $(stat -c %a /etc/pihole) = 700")
        server.succeed("! grep -R -F -- '$BALLOON-SHA256$' /etc/pihole/pihole.toml")
        server.succeed("test $(readlink /etc/pihole/cli_pw) = /run/pihole-cli/cli_pw; test -s /run/pihole-cli/cli_pw")
        server.succeed("test $(stat -c %a /run/pihole-cli) = 700; test -s /run/pihole-FTL.pid")

    with subtest("trusted HTTPS, LAN allowlist and observable DNS"):
        import shlex
        dns("pihole.home.arpa", expected="192.168.1.196")
        client.fail("curl --connect-timeout 2 https://pihole.home.arpa:8443/admin/")
        server.succeed(
            "umask 077; cd /var/lib/pihole; "
            "openssl req -x509 -newkey rsa:2048 -noenc -keyout /run/test-ca.key -out ordis-ca.crt -days 2 -subj /CN=Test-CA; "
            "openssl req -new -newkey rsa:2048 -noenc -keyout /run/test-leaf.key -out /run/test-leaf.csr -subj /CN=pihole.home.arpa; "
            "printf 'subjectAltName=DNS:pihole.home.arpa\\nextendedKeyUsage=serverAuth\\n' >/run/test-leaf.ext; "
            "openssl x509 -req -in /run/test-leaf.csr -CA ordis-ca.crt -CAkey /run/test-ca.key -days 1 -extfile /run/test-leaf.ext -out /run/test-leaf.crt; "
            "cat /run/test-leaf.crt /run/test-leaf.key >ordis-tls.pem; chgrp pihole ordis-tls.pem ordis-ca.crt; chmod 640 ordis-tls.pem ordis-ca.crt; "
            "systemctl restart pihole-ftl"
        )
        ca = shlex.quote(server.succeed("cat /var/lib/pihole/ordis-ca.crt"))
        client.succeed(f"printf %s {ca} > /run/test-ca.crt; ip addr add 192.168.1.10/24 dev eth1")
        endpoint = "https://pihole.home.arpa:8443/admin/"
        resolve = "--resolve pihole.home.arpa:8443:192.168.1.196"
        verified = f"curl -fsSL --max-time 3 --cacert /run/test-ca.crt {resolve}"
        client.succeed(f"{verified} --interface 192.168.1.65 {endpoint} -o /dev/null")
        client.fail(f"{verified} --interface 192.168.1.10 {endpoint}")
        client.fail(f"curl -fsS --max-time 3 {resolve} {endpoint}")
        server.succeed("ss -ltn | grep '192.168.1.196:8443'; ss -ltn | grep '127.0.0.1:8080'")
        server.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):8443'")
        operational()
        server.wait_until_succeeds(
            "sqlite3 /var/lib/pihole/pihole-FTL.db \"SELECT count(DISTINCT domain) FROM queries WHERE client='192.168.1.65' AND domain IN ('allowed.fixture.example.com','ads.fixture.example.com')\" | grep -Fx 2",
            timeout=100,
        )
        server.succeed("grep -E '^[[:space:]]*DBinterval = 60$' /etc/pihole/pihole.toml; grep -E '^[[:space:]]*maxDBdays = 7$' /etc/pihole/pihole.toml")

    with subtest("untrusted interface and IPv6 transport are denied"):
        # Add isolated addresses; these never reach the physical LAN.
        server.succeed("ip addr add 192.168.2.196/24 dev eth2; ip -6 addr add fd00:1::196/64 dev eth1 nodad")
        client.succeed("ip -6 addr add fd00:1::10/64 dev eth1 nodad")
        client.succeed("ping -6 -c 1 fd00:1::196")
        outside.succeed("ip addr add 192.168.2.10/24 dev eth1")
        outside.fail("curl --max-time 3 https://192.168.2.196:8443/admin/")
        client.fail("curl --max-time 3 'https://[fd00:1::196]:8443/admin/'")
        for transport in ["", "+tcp"]:
            outside.fail(f"dig @192.168.2.196 allowed.fixture.example.com +time=1 +tries=1 {transport}")
            client.fail(f"dig @fd00:1::196 allowed.fixture.example.com +time=1 +tries=1 {transport}")

    with subtest("persistent database data and service recovery"):
        server.succeed("sqlite3 /var/lib/pihole/gravity.db \"INSERT INTO domainlist(type,domain,enabled,comment) VALUES(1,'persist.fixture.example.com',1,'persistence-marker');\"")
        server.succeed("systemctl restart pihole-ftl")
        server.wait_for_unit("pihole-ftl.service")
        operational()
        dns("persist.fixture.example.com", expected="0.0.0.0")
        server.succeed("sha256sum /var/lib/pihole-secrets/admin-hash /etc/pihole/pihole.toml > /var/lib/pihole-secrets/checksums")
        server.succeed("systemctl kill --signal=SIGKILL pihole-ftl.service")
        server.wait_until_succeeds("systemctl is-active --quiet pihole-ftl.service")
        operational()

    with subtest("reboot retains credential, declarative config, gravity and custom entry"):
        old_boot = server.succeed("cat /proc/sys/kernel/random/boot_id").strip()
        server.shutdown()
        server.start()
        server.wait_for_unit("pihole-ftl.service")
        server.succeed("systemctl start pihole-ftl-setup.service")
        operational()
        dns("persist.fixture.example.com", expected="0.0.0.0")
        assert server.succeed("cat /proc/sys/kernel/random/boot_id").strip() != old_boot
        server.succeed("sha256sum -c /var/lib/pihole-secrets/checksums")
        server.succeed("sqlite3 /var/lib/pihole/gravity.db \"SELECT comment FROM domainlist WHERE domain='persist.fixture.example.com'\" | grep -Fx persistence-marker")
        server.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/stats/summary) = 401")
        client.fail("curl --fail --connect-timeout 2 http://192.168.1.196:8080/")

    with subtest("invalid lists shape fails before gravity update"):
        gravity_state = "umask 077; python3 ${./pihole-gravity-state.py} {} /run/gravity-before.json"
        server.succeed("python3 ${./pihole-test-invalid-lists.py}")
        print(server.succeed(gravity_state.format("before")))
        server.fail("systemctl start pihole-ftl-setup.service")
        server.succeed("test $(systemctl show -p Result --value pihole-ftl-setup) = exit-code && journalctl -b -u pihole-ftl-setup --grep='^Invalid list API response' -q --no-pager -o cat | grep -q '^Invalid list API response'")
        print(server.succeed(gravity_state.format("after")))
        server.succeed("rm /run/systemd/system/pihole-ftl-setup.service.d/90-test-invalid-lists.conf; systemctl daemon-reload")

    with subtest("scheduled Gravity publishes new domains and rejects bad downloads"):
        url = "http://192.168.1.50:8888/hosts"
        server.succeed(
            "install -d /run/systemd/system/pihole-ftl-setup.service.d; "
            "cp $(systemctl show -P ExecStart pihole-ftl-setup | cut -d' ' -f2 | cut -d= -f2) /run/managed-setup; "
            "sed -i -E 's@file:///nix/store/[a-z0-9]+-hosts@" + url + "@g' /run/managed-setup; "
            "printf '%s\\n' '[Service]' 'ExecStart=' 'ExecStart=/run/managed-setup' 'Environment=PIHOLE_MANAGED_HOSTS_URL=" + url + "' "
            "> /run/systemd/system/pihole-ftl-setup.service.d/90-fixture.conf; systemctl daemon-reload; "
            "sqlite3 /var/lib/pihole/gravity.db \"UPDATE adlist SET comment='StevenBlack unified hosts snapshot (35c74714)'\""
        )
        upstream.succeed("install -d /run/hosts-fixture; awk 'BEGIN{for(i=1;i<=50001;i++)printf \"0.0.0.0 fixture%d.example.com\\n\",i; print \"0.0.0.0 ads.fixture.example.com\"}' >/run/hosts-fixture/hosts; systemctl start hosts-fixture")
        upstream.wait_for_open_port(8888)
        server.succeed(
            "printf '%s\\n' '[Timer]' 'OnActiveSec=1' 'AccuracySec=1s' >/run/systemd/system/pihole-ftl-setup.timer; "
            "systemctl daemon-reload; systemctl start pihole-ftl-setup.timer"
        )
        dns("fixture50001.example.com", expected="0.0.0.0")
        server.succeed(f"sqlite3 /var/lib/pihole/gravity.db 'SELECT address FROM adlist' | grep -Fx {url}")
        server.succeed("sha256sum /var/lib/pihole/gravity.db /etc/pihole/listsCache/*.domains >/run/last-working")
        for break_source in [
            "printf '<html>bad response</html>\\n' >/run/hosts-fixture/hosts",
            "rm /run/hosts-fixture/hosts",
            "systemctl stop hosts-fixture",
        ]:
            upstream.succeed(break_source)
            server.fail("systemctl start pihole-ftl-setup")
            server.succeed("sha256sum -c /run/last-working")
            dns("fixture50001.example.com", expected="0.0.0.0")
        operational()
  '';
}
