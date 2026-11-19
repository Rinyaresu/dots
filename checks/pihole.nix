{
  pkgs,
  piholeModule,
  ordis,
  experiment ? "off",
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
      systemd.services.pihole-ftl-setup.serviceConfig.LogFilterPatterns = lib.mkIf (experiment != "off") [ "^META " "^Invalid list API response" ];
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
          interface = "eth1";
          upstreams = lib.mkForce [ "192.168.1.50#5353" ];
        };
        macvendorURL = "file:///dev/null";
        lists = [
          {
            url = "file://${pkgs.writeText "test-blocklist" "0.0.0.0 ads.fixture.example.com\n"}";
            description = "Deterministic integration fixture";
          }
        ];
      };
      environment.systemPackages = [
        pkgs.dig
        pkgs.sqlite
        pkgs.python3
        pkgs.curl
      ];
    };
    client = { lib, ... }: {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.10";
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
      networking.firewall.allowedTCPPorts = [ 5353 ];
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

    experiment = "${experiment}"
    install_setup = "python3 ${./pihole-test-setup.py} {} ${./pihole-observe.py}"
    if experiment == "observe":
        server.succeed(install_setup.format("observe"))

    # Random test-only password exists in VM RAM, never in a derivation or argv.
    server.succeed("python3 ${./pihole-provision.py}")
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
            if experiment == "off":
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

    with subtest("untrusted interface and IPv6 transport are denied"):
        # Add isolated addresses; these never reach the physical LAN.
        server.succeed("ip addr add 192.168.2.196/24 dev eth2; ip -6 addr add fd00:1::196/64 dev eth1 nodad")
        client.succeed("ip -6 addr add fd00:1::10/64 dev eth1 nodad")
        client.succeed("ping -6 -c 1 fd00:1::196")
        outside.succeed("ip addr add 192.168.2.10/24 dev eth1")
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

    def metadata():
        if experiment == "off":
            return
        server.succeed("grep -F 'Hypervisor detected: KVM' /dev/null || journalctl -k -b --grep='Hypervisor detected: KVM' --no-pager -o cat | grep -q KVM")
        print('BOOTMETA mode=' + experiment + ' id=' + server.succeed('cat /proc/sys/kernel/random/boot_id').strip())
        print(server.succeed("systemctl show pihole-ftl pihole-ftl-setup -p Id -p MainPID -p ActiveState -p SubState -p Result -p ExecMainStatus -p ExecMainStartTimestampMonotonic -p InvocationID; journalctl -b -u pihole-ftl-setup -o short-monotonic --no-pager --grep='^META |^Invalid list API response' || true"))

    def checked_setup():
        try:
            if experiment != "off":
                server.fail("systemctl is-failed --quiet pihole-ftl-setup")
            server.succeed("systemctl start pihole-ftl-setup.service")
        finally:
            metadata()

    with subtest("reboot retains credential, declarative config, gravity and custom entry"):
        metadata()
        old_boot = server.succeed("cat /proc/sys/kernel/random/boot_id").strip()
        server.shutdown()
        server.start()
        server.wait_for_unit("pihole-ftl.service")
        checked_setup()
        operational()
        dns("persist.fixture.example.com", expected="0.0.0.0")
        assert server.succeed("cat /proc/sys/kernel/random/boot_id").strip() != old_boot
        server.succeed("sha256sum -c /var/lib/pihole-secrets/checksums")
        server.succeed("sqlite3 /var/lib/pihole/gravity.db \"SELECT comment FROM domainlist WHERE domain='persist.fixture.example.com'\" | grep -Fx persistence-marker")
        server.succeed("test $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/stats/summary) = 401")
        client.fail("curl --fail --connect-timeout 2 http://192.168.1.196:8080/")

    if experiment != "off":
        with subtest("three further reboots keep setup and DNS working"):
            seen = {old_boot, server.succeed('cat /proc/sys/kernel/random/boot_id').strip()}
            for _ in range(3):
                server.shutdown()
                server.start()
                server.wait_for_unit("pihole-ftl.service")
                checked_setup()
                boot = server.succeed('cat /proc/sys/kernel/random/boot_id').strip()
                assert boot not in seen
                seen.add(boot)
                operational()
                dns("persist.fixture.example.com", expected="0.0.0.0")

    if experiment == "control":
        with subtest("invalid lists shape fails before gravity update"):
            server.succeed("test -s /var/lib/pihole/gravity.db; umask 077; sha256sum /var/lib/pihole/gravity.db > /run/gravity-before")
            server.succeed(install_setup.format("invalid"))
            server.fail("systemctl start pihole-ftl-setup.service")
            server.succeed("test $(systemctl show -p Result --value pihole-ftl-setup) = exit-code; journalctl -b -u pihole-ftl-setup --grep='^Invalid list API response' -q --no-pager -o cat | grep -q '^Invalid list API response'; sha256sum --status -c /run/gravity-before")
  '';
}
