{ nixos }:
{
  name = "ordis-tailscale-firewall";
  # The real host declares nixpkgs.hostPlatform and nixpkgs.config itself.
  node.pkgsReadOnly = false;

  nodes.machine = { lib, pkgs, ... }: {
    imports = [ nixos.host-ordis ];
    # The VM has no physical eno1; the test creates it and the overlay as
    # veth peers in isolated namespaces. No Tailscale identity is provisioned.
    virtualisation.vlans = lib.mkForce [ ];
    virtualisation.restrictNetwork = true;
    networking.networkmanager.unmanaged = [
      "interface-name:eno1"
      "interface-name:tailscale0"
    ];
    # Exercise both selected capabilities, with deterministic offline DNS data.
    networking.hosts."192.0.2.1" = [
      "raw.githubusercontent.com"
      "github.com"
    ];
    services.pihole-ftl = {
      lists = lib.mkForce [
        {
          url = "file://${pkgs.writeText "tailscale-test-blocklist" "0.0.0.0 ads.fixture.example.com\n"}";
          description = "Pi-hole and Tailscale coexistence fixture";
        }
      ];
      settings.dns.upstreams = lib.mkForce [ ];
    };
    environment.systemPackages = [
      pkgs.python3
      pkgs.dig
      pkgs.curl
      pkgs.jq
      pkgs.netcat-openbsd
      pkgs.iproute2
    ];
  };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("tailscaled.service")
    machine.fail("systemctl cat tailscaled-set.service")
    machine.succeed("systemctl show tailscaled.service -p StateDirectory --value | grep -x tailscale")
    machine.succeed("test -d /var/lib/tailscale")
    def check_prefs():
        prefs = json.loads(machine.succeed("curl -fsS --unix-socket /run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/prefs"))
        assert prefs["CorpDNS"] is False, prefs
        assert prefs["RouteAll"] is False, prefs
        assert prefs["RunSSH"] is False, prefs
        assert prefs["RunWebClient"] is False, prefs
        assert prefs["AdvertiseRoutes"] in (None, []), prefs
        assert not prefs["ExitNodeID"] and not prefs["ExitNodeIP"], prefs
        assert prefs["NetfilterMode"] == 0, prefs
        assert prefs["RemoteConfig"] is False, prefs
        assert prefs["AutoUpdate"]["Check"] is False, prefs
        assert prefs["AutoUpdate"]["Apply"] is False, prefs

    machine.wait_until_succeeds("curl -fsS --unix-socket /run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/prefs >/dev/null")
    check_prefs()
    machine.succeed("if tailscale set --accept-dns=true > /tmp/set-output 2>&1; then exit 1; fi; grep -i 'config file is locked' /tmp/set-output")
    check_prefs()
    # The locked configuration does not support `tailscale up` or `login`.
    # Initiate the backend flow directly, without logging a response or URL.
    machine.succeed("timeout 10 tailscale debug localapi POST login-interactive >/dev/null 2>&1")
    check_prefs()

    # Compare the resolver with the actual service stopped and restarted.
    machine.succeed("set -e; echo retained > /var/lib/tailscale/vm-test-marker; systemctl stop tailscaled.service; cp -L /etc/resolv.conf /tmp/resolv.before; systemctl start tailscaled.service")
    machine.wait_for_unit("tailscaled.service")
    machine.succeed("cmp /tmp/resolv.before /etc/resolv.conf")
    machine.wait_until_succeeds("curl -fsS --unix-socket /run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/prefs >/dev/null")
    # Inspect the daemon immediately after restart, with no reapplication unit.
    check_prefs()
    machine.succeed("cmp /tmp/resolv.before /etc/resolv.conf")
    machine.succeed("test \"$(cat /var/lib/tailscale/vm-test-marker)\" = retained")
    machine.wait_for_unit("sshd.service")
    for addr, methods, password in [
        ("100.64.0.2", "publickey", "no"),
        ("fd7a:115c:a1e0::2", "publickey", "no"),
        ("192.168.1.65", "publickey", "no"),
        ("192.168.1.10", "publickey", "no"),
        ("2001:db8::10", "publickey", "no"),
    ]:
        sshd_config = machine.succeed(f"sshd -T -C user=ordis,addr={addr},host=ordis")
        settings = dict((key.lower(), value) for key, value in (line.split(" ", 1) for line in sshd_config.splitlines()))
        assert settings.get("authenticationmethods") == methods, (addr, settings)
        assert settings["passwordauthentication"] == password, (addr, settings)
        assert settings["permitrootlogin"] == "no", (addr, settings)
        assert settings["allowagentforwarding"] == "no", (addr, settings)
        assert settings["allowtcpforwarding"] == "yes", (addr, settings)
        if password == "no":
            assert settings["kbdinteractiveauthentication"] == "no", (addr, settings)

    # Listeners let blocked cases distinguish firewall drops from closed ports.
    machine.succeed("nc -lk -p 23456 >/dev/null 2>&1 &")
    machine.succeed("set -e; ip netns add lan; ip link add eno1 type veth peer name lan-peer; ip link set lan-peer netns lan")
    machine.succeed("set -e; ip addr add 192.168.1.196/24 dev eno1; ip addr add 192.168.2.196/24 dev eno1; ip -6 addr add 2001:db8:1::196/64 dev eno1 nodad; ip link set eno1 up")
    machine.succeed("set -e; ip -n lan link set lo up; ip -n lan link set lan-peer up; ip -n lan addr add 192.168.1.10/24 dev lan-peer; ip -n lan addr add 192.168.1.65/24 dev lan-peer; ip -n lan addr add 192.168.2.10/24 dev lan-peer; ip -n lan -6 addr add 2001:db8:1::10/64 dev lan-peer nodad")
    # Keep the real daemon running, but move its unauthenticated TUN aside so
    # the test can inject packets through a veth with the real interface name.
    machine.succeed("set -e; ip link set tailscale0 down; ip link set tailscale0 name ts-real; ip netns add overlay; ip link add tailscale0 type veth peer name overlay-peer; ip link set overlay-peer netns overlay")
    machine.succeed("set -e; ip addr add 100.64.0.1/24 dev tailscale0; ip -6 addr add fd7a:115c:a1e0::1/64 dev tailscale0 nodad; ip link set tailscale0 up; ip -n overlay link set lo up; ip -n overlay link set overlay-peer up; ip -n overlay addr add 100.64.0.2/24 dev overlay-peer; ip -n overlay -6 addr add fd7a:115c:a1e0::2/64 dev overlay-peer nodad")
    machine.wait_until_succeeds("nc -w 2 -z 127.0.0.1 23456")
    machine.wait_until_succeeds("ip netns exec lan nc -w 2 -z -s 192.168.1.65 192.168.1.196 22")
    machine.fail("ip netns exec lan nc -w 2 -z -s 192.168.1.10 192.168.1.196 22")
    # eno1 has a return route to 192.168.2.0/24, so this is not an rp_filter artifact.
    machine.fail("ip netns exec lan nc -w 2 -z -s 192.168.2.10 192.168.1.196 22")
    machine.fail("ip netns exec lan nc -w 2 -z -s 192.168.1.65 192.168.2.196 22")
    machine.succeed("ip netns exec lan ping -6 -c 1 -W 2 2001:db8:1::196")
    machine.fail("ip netns exec lan nc -6 -w 2 -z -s 2001:db8:1::10 2001:db8:1::196 22")
    machine.wait_until_succeeds("ip netns exec overlay nc -w 2 -z 100.64.0.1 22")
    machine.fail("ip netns exec overlay nc -w 2 -z 100.64.0.1 23456")
    machine.wait_until_succeeds("ip netns exec overlay nc -6 -w 2 -z fd7a:115c:a1e0::1 22")
    machine.succeed("nc -6 -lk -p 23456 >/dev/null 2>&1 &")
    machine.wait_until_succeeds("nc -6 -w 2 -z ::1 23456")
    machine.fail("ip netns exec overlay nc -6 -w 2 -z fd7a:115c:a1e0::1 23456")

    with subtest("Pi-hole and Tailscale coexist without widening DNS access"):
        machine.succeed("python3 ${./pihole-provision.py}")
        machine.succeed("systemctl reset-failed pihole-ftl pihole-ftl-setup; systemctl restart pihole-ftl")
        machine.wait_for_unit("pihole-ftl.service")
        def lan_dns():
            for transport in ["", "+tcp"]:
                machine.wait_until_succeeds(f"ip netns exec lan dig @192.168.1.196 ads.fixture.example.com +short +time=1 +tries=1 {transport} | grep -Fx 0.0.0.0", timeout=60)
        lan_dns()
        check_prefs()
        machine.succeed("curl -fsSL http://127.0.0.1:8080/ >/dev/null")
        for transport in ["", "+tcp"]:
            machine.fail(f"ip netns exec overlay dig @100.64.0.1 ads.fixture.example.com +time=1 +tries=1 {transport}")
            machine.fail(f"ip netns exec lan dig @2001:db8:1::196 ads.fixture.example.com +time=1 +tries=1 {transport}")
        # Restore the daemon's real TUN before restarting it; the veth was only
        # a packet-injection fixture, never a real tailnet or authenticated peer.
        machine.succeed("ip link set tailscale0 down; ip link set tailscale0 name ts-fixture; ip link set ts-real name tailscale0; systemctl restart tailscaled.service")
        machine.wait_for_unit("tailscaled.service")
        machine.wait_until_succeeds("curl -fsS --unix-socket /run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/prefs >/dev/null")
        check_prefs()
        machine.succeed("cmp /tmp/resolv.before /etc/resolv.conf")
        lan_dns()
        machine.succeed("systemctl is-active pihole-ftl.service")
    machine.succeed("test -z \"$(systemctl --failed --no-legend --plain)\"")
  '';
}
