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
      imports = [
        piholeModule
        (import ../modules/hosts/ordis/_pihole-link-local.nix {
          interface = "eth1";
          address = "fe80::196:53";
        })
      ];
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
      # Keep production IPv4 ingress; the imported module supplies IPv6 rules.
      networking.firewall.extraCommands =
        lib.concatMapStringsSep "\n" (builtins.replaceStrings [ "eno1" ] [ "eth1" ])
          (
            builtins.filter (lib.hasPrefix "iptables ") (
              lib.splitString "\n" ordis.networking.firewall.extraCommands
            )
          );
      services.pihole-ftl = {
        settings.dns = {
          inherit (ordis.services.pihole-ftl.settings.dns) hosts queryLogging;
          interface = "eth1";
          upstreams = lib.mkForce [ "192.168.1.50#5353" ];
        };
        inherit (ordis.services.pihole-ftl) privacyLevel;
        settings = {
          inherit (ordis.services.pihole-ftl.settings) database;
          webserver.tls.cert = lib.mkForce "/var/lib/pihole-tls/server.pem";
          misc.dnsmasq_lines = ordis.services.pihole-ftl.settings.misc.dnsmasq_lines;
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
        PIHOLE_TLS_CA = "/var/lib/pihole-tls/test-ca.crt";
      };
      systemd.services.pihole-publish-tls = {
        serviceConfig = ordis.systemd.services.pihole-publish-tls.serviceConfig // {
          ExecStart =
            builtins.replaceStrings
              [ "/var/lib/acme/pihole.rinyaresu.dev" "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ]
              [ "/run/test-acme" "/var/lib/pihole-tls/test-ca.crt" ]
              ordis.systemd.services.pihole-publish-tls.serviceConfig.ExecStart;
        };
      };
      systemd.tmpfiles.rules = [ "d /var/lib/pihole-tls 0750 root pihole -" ];
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
        dns("pihole.rinyaresu.dev", expected="192.168.1.196")
        client.fail("curl --max-time 2 --resolve pihole.rinyaresu.dev:443:192.168.1.196 https://pihole.rinyaresu.dev/admin/")
        server.fail("ss -ltn | grep ':443 '")
        ca_path = "/var/lib/pihole-tls/test-ca.crt"
        server.succeed(
            f"umask 077; mkdir /run/test-acme; cd /run/test-acme; "
            f"openssl req -x509 -newkey rsa:2048 -noenc -keyout /run/test-ca.key -out {ca_path} -days 4 -subj /CN=Test-CA; "
            f"chgrp pihole {ca_path}; chmod 640 {ca_path}; "
            "openssl req -new -newkey rsa:2048 -noenc -keyout key.pem -out leaf.csr -subj /CN=pihole.rinyaresu.dev; "
            "printf 'subjectAltName=DNS:pihole.rinyaresu.dev\\nextendedKeyUsage=serverAuth\\n' >leaf.ext"
        )
        def issue(serial: int) -> None:
            server.succeed(f"cd /run/test-acme; openssl x509 -req -in leaf.csr -CA {ca_path} -CAkey /run/test-ca.key -days 3 -set_serial {serial} -extfile leaf.ext -out fullchain.pem")
        issue(1)
        server.fail("systemctl start pihole-publish-tls")
        server.succeed("touch /run/test-acme/acme-success; systemctl start pihole-publish-tls")
        ca = shlex.quote(server.succeed(f"cat {ca_path}"))
        client.succeed(f"printf %s {ca} > /run/test-ca.crt; ip addr add 192.168.1.10/24 dev eth1")
        endpoint = "https://pihole.rinyaresu.dev/admin/"
        resolve = "--resolve pihole.rinyaresu.dev:443:192.168.1.196"
        verified = f"curl -fsSL --max-time 3 --cacert /run/test-ca.crt {resolve}"
        client.succeed(f"{verified} --interface 192.168.1.65 {endpoint} -o /dev/null")
        client.fail(f"{verified} --interface 192.168.1.10 {endpoint}")
        client.fail(f"curl -fsS --max-time 3 {resolve} {endpoint}")
        server.succeed("ss -ltn | grep '192.168.1.196:443'; ss -ltn | grep '127.0.0.1:8080'")
        server.fail("ss -ltn | grep -E '(0.0.0.0|\\*|\\[::\\]):443 '")
        pid = server.succeed("systemctl show -P MainPID pihole-ftl").strip()
        server.succeed("systemctl start pihole-publish-tls")
        assert server.succeed("systemctl show -P MainPID pihole-ftl").strip() == pid
        server.succeed("cp /run/test-acme/key.pem /run/test-key-save; cp /run/test-ca.key /run/test-acme/key.pem; sha256sum /var/lib/pihole-tls/server.pem >/run/tls-digest")
        server.fail("systemctl start pihole-publish-tls")
        server.succeed("sha256sum -c /run/tls-digest; mv /run/test-key-save /run/test-acme/key.pem")
        assert server.succeed("systemctl show -P MainPID pihole-ftl").strip() == pid
        issue(2)
        server.succeed("systemctl start pihole-publish-tls; openssl x509 -in /var/lib/pihole-tls/server.pem -noout -serial | grep -Fx serial=02")
        assert server.succeed("systemctl show -P MainPID pihole-ftl").strip() != pid
        client.succeed(f"{verified} --interface 192.168.1.65 {endpoint} -o /dev/null")
        operational()
        server.wait_until_succeeds(
            "sqlite3 /var/lib/pihole/pihole-FTL.db \"SELECT count(DISTINCT domain) FROM queries WHERE client='192.168.1.65' AND domain IN ('allowed.fixture.example.com','ads.fixture.example.com')\" | grep -Fx 2",
            timeout=100,
        )
        server.succeed(
            "umask 077; curl -fsS -H 'Content-Type: application/json' --data-binary @/run/test-auth.json http://127.0.0.1:8080/api/auth "
            "| jq -er '.session.sid | \"sid: \\(.)\"' >/run/session-header"
        )
        for suffix in ["", "?blocked=true"]:
            server.succeed(
                f"curl -fsS -H @/run/session-header 'http://127.0.0.1:8080/api/stats/top_clients{suffix}' "
                "| jq -e 'any(.clients[]; .ip == \"192.168.1.65\" and .count > 0)'"
            )
        server.succeed("grep -E '^[[:space:]]*DBinterval = 60$' /etc/pihole/pihole.toml; grep -E '^[[:space:]]*maxDBdays = 7$' /etc/pihole/pihole.toml")

    with subtest("dedicated IPv6 link-local DNS works for both LAN source scopes"):
        server.wait_for_unit("pihole-link-local.service")
        server.succeed("ip -6 addr del fe80::196:53/128 dev eth1; systemctl reload pihole-link-local.service")
        server.wait_until_succeeds("ip -6 -o addr show dev eth1 to fe80::196:53/128 -tentative | grep -F 'fe80::196:53/128'")
        server.succeed("ip -6 addr add 2001:db8:1::196/64 dev eth1 nodad")
        client.succeed("ip -6 addr add 2001:db8:1::10/64 dev eth1 nodad")
        for transport in ["+notcp", "+tcp"]:
            for source in ["", "-b 2001:db8:1::10"]:
                client.succeed(
                    f"dig {source} @fe80::196:53%eth1 allowed.fixture.example.com AAAA +short +time=2 +tries=1 {transport} | grep -Fx 2001:db8::42"
                )

    with subtest("untrusted interface, non-allowlisted IPv6 destinations and IPv6 web are denied"):
        # Give the off-LAN interface the same destination, to test the ingress
        # rule rather than absence of an address or IPv6 routing.
        server.succeed("ip addr add 192.168.2.196/24 dev eth2; ip -6 addr add fe80::196:53/128 dev eth2 nodad; ip -6 addr add fe80::197/128 dev eth1 nodad")
        client.succeed("ping -6 -c 1 2001:db8:1::196; ping -6 -I eth1 -c 1 fe80::197")
        outside.succeed("ip addr add 192.168.2.10/24 dev eth1; ping -6 -I eth1 -c 1 fe80::196:53")
        outside.fail("curl -k --max-time 3 https://192.168.2.196/admin/")
        client.fail("curl -k --max-time 3 'https://[2001:db8:1::196]/admin/'")
        for transport in ["+notcp", "+tcp"]:
            outside.fail(f"dig @192.168.2.196 allowed.fixture.example.com +time=1 +tries=1 {transport}")
            outside.fail(f"dig @fe80::196:53%eth1 allowed.fixture.example.com +time=1 +tries=1 {transport}")
            for destination in ["2001:db8:1::196", "fe80::197%eth1"]:
                client.fail(f"dig @{destination} allowed.fixture.example.com +time=1 +tries=1 {transport}")
        server.succeed("ip -6 addr del fe80::196:53/128 dev eth2")
        server.succeed("systemctl stop pihole-link-local.service; test -z \"$(ip -6 addr show dev eth1 to fe80::196:53/128)\"")
        server.succeed("systemctl start pihole-link-local.service")

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
        gambling_url = "http://192.168.1.50:8888/gambling"
        managed_sql = "${ordis.systemd.services.pihole-ftl-setup.environment.PIHOLE_MANAGED_LISTS_SQL}"
        server.succeed(
            "install -d /run/systemd/system/pihole-ftl-setup.service.d; "
            "cp $(systemctl show -P ExecStart pihole-ftl-setup | cut -d' ' -f2 | cut -d= -f2) /run/managed-setup; "
            "sed -i -E 's@file:///nix/store/[a-z0-9]+-hosts@" + url + "@g' /run/managed-setup; "
            f"sed -E 's@https://cdn[.]jsdelivr[.]net/gh/hagezi/dns-blocklists.latest/adblock/pro[.]txt@{url}@g;"
            f"s@https://cdn[.]jsdelivr[.]net/gh/hagezi/dns-blocklists.latest/adblock/gambling[.]medium[.]txt@{gambling_url}@g' {managed_sql} >/run/managed-lists.sql; "
            "printf '%s\\n' '[Service]' 'ExecStart=' 'ExecStart=/run/managed-setup' "
            f"'Environment=PIHOLE_MANAGED_PRO_URL={url}' 'Environment=PIHOLE_MANAGED_GAMBLING_URL={gambling_url}' "
            "'Environment=PIHOLE_MANAGED_LISTS_SQL=/run/managed-lists.sql' "
            "> /run/systemd/system/pihole-ftl-setup.service.d/90-fixture.conf; systemctl daemon-reload; "
            "sqlite3 /var/lib/pihole/gravity.db \"UPDATE adlist SET comment='StevenBlack unified hosts snapshot (35c74714)'; "
            "INSERT INTO [group](id,name) VALUES(42,'extra'); "
            "INSERT INTO adlist_by_group SELECT id,42 FROM adlist; "
            "INSERT INTO domainlist(type,domain) VALUES(0,'allowed.fixture.example.com'); "
            "INSERT INTO domainlist_by_group SELECT id,42 FROM domainlist WHERE type=0;\""
        )
        upstream.succeed("install -d /run/hosts-fixture; awk 'BEGIN{for(i=1;i<=50001;i++)printf \"||fixture%d.example.com^\\n\",i; print \"||ads.fixture.example.com^\"}' >/run/hosts-fixture/hosts; systemctl start hosts-fixture")
        server.wait_until_succeeds("curl -fsS --max-time 2 http://192.168.1.50:8888/hosts -o /dev/null")
        server.succeed("sha256sum /var/lib/pihole/gravity.db /var/lib/pihole/listsCache/*.domains >/run/before-migration")
        server.fail("systemctl start pihole-ftl-setup")
        server.succeed("sha256sum -c /run/before-migration")
        upstream.succeed("awk 'BEGIN{for(i=1;i<=50001;i++)printf \"||wager%d.example.com^\\n\",i}' >/run/hosts-fixture/gambling")
        server.succeed(
            "printf '%s\\n' '[Timer]' 'OnActiveSec=1' 'AccuracySec=1s' >/run/systemd/system/pihole-ftl-setup.timer; "
            "systemctl daemon-reload; systemctl start pihole-ftl-setup.timer"
        )
        dns("fixture50001.example.com", expected="0.0.0.0")
        dns("wager50001.example.com", expected="0.0.0.0")
        dns("wager50001.example.com", "AAAA", tcp=True, expected="::")
        sql = "sqlite3 /var/lib/pihole/gravity.db"
        assert server.succeed(f"{sql} 'SELECT id,address FROM adlist ORDER BY id'").splitlines() == [f"1|{url}", f"2|{gambling_url}"]
        assert server.succeed(f"{sql} 'SELECT * FROM adlist_by_group ORDER BY adlist_id,group_id'").splitlines() == ["1|0", "1|42", "2|0", "2|42"]
        server.succeed(f"{sql} 'SELECT count(*) FROM domainlist_by_group WHERE group_id=42' | grep -Fx 1")
        server.succeed("sha256sum /var/lib/pihole/gravity.db /var/lib/pihole/listsCache/*.domains >/run/last-working")
        upstream.succeed("mv /run/hosts-fixture/gambling /run/gambling-working; printf '<html>error</html>\\n' >/run/hosts-fixture/gambling")
        server.fail("systemctl start pihole-ftl-setup")
        server.succeed("sha256sum -c /run/last-working")
        dns("wager50001.example.com", expected="0.0.0.0")
        upstream.succeed("mv /run/gambling-working /run/hosts-fixture/gambling")
        for break_source in [
            "printf '<html>bad response</html>\\n' >/run/hosts-fixture/hosts",
            "rm /run/hosts-fixture/hosts",
            "systemctl stop hosts-fixture",
        ]:
            upstream.succeed(break_source)
            server.fail("systemctl start pihole-ftl-setup")
            server.succeed("sha256sum -c /run/last-working")
            dns("fixture50001.example.com", expected="0.0.0.0")
        upstream.succeed("awk 'BEGIN{for(i=1;i<=50002;i++)printf \"||fixture%d.example.com^\\n\",i; print \"||ads.fixture.example.com^\"}' >/run/hosts-fixture/hosts; systemctl start hosts-fixture")
        server.wait_until_succeeds("curl -fsS --max-time 2 http://192.168.1.50:8888/hosts -o /dev/null")
        server.succeed("systemctl start pihole-ftl-setup")
        dns("fixture50002.example.com", expected="0.0.0.0")
        operational()

    with subtest("SIGKILL at the Gravity publication boundary leaves a usable database"):
        script = "${ordis.services.pihole-ftl.piholePackage}/share/pihole/advanced/Scripts/gravity.sh"
        db = "/var/lib/pihole/gravity.db"
        backup = "/var/lib/pihole/gravity_old.db"
        upstream.succeed(
            "printf '||interrupted.example.com^\\n' >>/run/hosts-fixture/hosts"
        )
        for after in [False, True]:
            # Only the VM uses an instrumented copy; inject SIGKILL at the live rename.
            source = server.succeed(f"cat {script}")
            lines = source.splitlines(keepends=True)
            index, = [
                i for i, line in enumerate(lines)
                if 'mv --no-copy -fT "${"$"}{gravityTEMPfile}" "${"$"}{gravityDBfile}"' in line
            ]
            lines.insert(index + int(after), '  kill -KILL "$$"\n')
            server.succeed("printf %s " + shlex.quote("".join(lines)) + " >/run/gravity-interrupt; chgrp pihole /run/gravity-interrupt; chmod 750 /run/gravity-interrupt")
            server.succeed(
                f"rc=0; PIHOLE_MANAGED_PRO_URL={url} PIHOLE_MANAGED_GAMBLING_URL={gambling_url} "
                "PIHOLE_MANAGED_LISTS_SQL=/run/managed-lists.sql "
                "bash /run/gravity-interrupt -g || rc=$?; test \"$rc\" = 137"
            )
            for path in [db, backup]:
                server.succeed(f"sqlite3 {path} 'PRAGMA quick_check' | grep -Fx ok")
                server.succeed(f"sqlite3 {path} \"SELECT count(*) FROM gravity WHERE domain='||fixture50002.example.com^'\" | grep -Fx 1")
            db_count = 1 if after else 0
            for path, count in [(db, db_count), (backup, 0)]:
                server.succeed(f"sqlite3 {path} \"SELECT count(*) FROM gravity WHERE domain='||interrupted.example.com^'\" | grep -Fx {count}")
            dns("fixture50002.example.com", expected="0.0.0.0")
        server.succeed("systemctl restart pihole-ftl")
        dns("interrupted.example.com", expected="0.0.0.0")
  '';
}
