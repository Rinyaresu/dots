import json

start_all()
machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("sshd.service")
machine.wait_for_unit("tailscaled.service")
machine.wait_until_succeeds(
    "curl -fsS --unix-socket /run/tailscale/tailscaled.sock "
    "http://local-tailscaled.sock/localapi/v0/prefs >/dev/null"
)
prefs = json.loads(machine.succeed(
    "curl -fsS --unix-socket /run/tailscale/tailscaled.sock "
    "http://local-tailscaled.sock/localapi/v0/prefs"
))
assert prefs["CorpDNS"] is False, prefs
assert prefs["RouteAll"] is False, prefs
assert prefs["RunSSH"] is False, prefs
assert prefs["NetfilterMode"] == 0, prefs
assert not prefs["ExitNodeID"] and not prefs["ExitNodeIP"], prefs
assert prefs["AdvertiseRoutes"] in (None, []), prefs
machine.succeed("set -eu; cp -L /etc/resolv.conf /tmp/resolv.before; systemctl restart tailscaled.service")
machine.wait_for_unit("tailscaled.service")
machine.succeed("cmp /tmp/resolv.before /etc/resolv.conf")

for addr in ["100.64.0.2", "fd7a:115c:a1e0::2", "192.0.2.2", "2001:db8:1::2"]:
    config = machine.succeed(f"sshd -T -C user=rinyaresu,addr={addr},host=desktop")
    settings = {key.lower(): value for key, value in
                (line.split(" ", 1) for line in config.splitlines())}
    assert "authenticationmethods" in settings, config
    assert settings["authenticationmethods"] == "publickey", settings
    assert settings["passwordauthentication"] == "no", settings
    assert settings["kbdinteractiveauthentication"] == "no", settings
    assert settings["permitrootlogin"] == "no", settings
    assert settings["allowagentforwarding"] == "no", settings
    assert settings["authorizedkeysfile"] == "/var/lib/desktop-ssh/authorized_keys/%u", settings

machine.succeed(
    "set -eu; ip link set tailscale0 down; ip link set tailscale0 name ts-real; "
    "ip netns add overlay; ip link add tailscale0 type veth peer name overlay-peer; "
    "ip link set overlay-peer netns overlay"
)
links = [
    ("overlay", "tailscale0", "overlay-peer", "100.64.0", "fd7a:115c:a1e0:1"),
    ("lan", "lan0", "lan-peer", "192.0.2", "2001:db8:1"),
    ("wan", "wan0", "wan-peer", "198.51.100", "2001:db8:2"),
]
for namespace, interface, peer, ipv4, ipv6 in links:
    if namespace != "overlay":
        machine.succeed(
            f"set -eu; ip netns add {namespace}; ip link add {interface} type veth peer name {peer}; "
            f"ip link set {peer} netns {namespace}"
        )
    machine.succeed(
        f"set -eu; ip addr add {ipv4}.1/24 dev {interface}; "
        f"ip -6 addr add {ipv6}::1/64 dev {interface} nodad; "
        f"ip link set {interface} up; ip -n {namespace} link set lo up; "
        f"ip -n {namespace} addr add {ipv4}.2/24 dev {peer}; "
        f"ip -n {namespace} -6 addr add {ipv6}::2/64 dev {peer} nodad; "
        f"ip -n {namespace} link set {peer} up"
    )

machine.succeed("nc -4 -lk -p 23456 >/dev/null 2>&1 &")
machine.succeed("nc -6 -lk -p 23456 >/dev/null 2>&1 &")
machine.wait_until_succeeds("nc -4 -w 2 -z 127.0.0.1 23456")
machine.wait_until_succeeds("nc -6 -w 2 -z ::1 23456")

def probe(namespace, address, port):
    family = "-6" if ":" in address else "-4"
    return f"ip netns exec {namespace} nc {family} -w 2 -z {address} {port}"

def check_firewall():
    for namespace, interface, peer, ipv4, ipv6 in links:
        for address in [f"{ipv4}.1", f"{ipv6}::1"]:
            if namespace == "overlay":
                machine.succeed(probe(namespace, address, 22))
            else:
                machine.fail(probe(namespace, address, 22))
            machine.fail(probe(namespace, address, 23456))

check_firewall()
with subtest("blocked ports have listeners and working return routes"):
    machine.succeed("systemctl stop firewall.service")
    try:
        for namespace, interface, peer, ipv4, ipv6 in links:
            for address in [f"{ipv4}.1", f"{ipv6}::1"]:
                for port in [22, 23456]:
                    machine.succeed(probe(namespace, address, port))
    finally:
        machine.succeed("systemctl start firewall.service")
check_firewall()

machine.succeed("ssh-keygen -q -t ed25519 -N '' -f /tmp/fixture-key")
machine.succeed(
    """awk '{print "desktop-fixture " $1 " " $2}' """
    "/etc/ssh/ssh_host_ed25519_key.pub > /tmp/known_hosts"
)
ssh = (
    "ip netns exec overlay ssh -n -i /tmp/fixture-key "
    "-o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=3 "
    "-o ControlMaster=no -o ControlPath=none -o ForwardAgent=no "
    "-o PreferredAuthentications=publickey -o StrictHostKeyChecking=yes "
    "-o HostKeyAlias=desktop-fixture -o UserKnownHostsFile=/tmp/known_hosts "
)
with subtest("only the external runtime authorization file permits login"):
    machine.fail(ssh + "rinyaresu@100.64.0.1 true")
    machine.succeed(
        "set -eu; install -d -m 0700 -o rinyaresu -g users /home/rinyaresu/.ssh; "
        "install -m 0600 -o rinyaresu -g users "
        "/tmp/fixture-key.pub /home/rinyaresu/.ssh/authorized_keys; "
        "install -d -m 0755 /etc/ssh/authorized_keys.d; "
        "install -m 0644 /tmp/fixture-key.pub /etc/ssh/authorized_keys.d/rinyaresu"
    )
    machine.fail(ssh + "rinyaresu@100.64.0.1 true")
    machine.succeed(
        "install -m 0644 -o root -g root "
        "/tmp/fixture-key.pub /var/lib/desktop-ssh/authorized_keys/rinyaresu"
    )
    assert machine.succeed(ssh + "rinyaresu@100.64.0.1 id -un").strip() == "rinyaresu"
    assert machine.succeed(ssh + "rinyaresu@fd7a:115c:a1e0:1::1 id -un").strip() == "rinyaresu"
    machine.succeed("install -m 0644 /tmp/fixture-key.pub /var/lib/desktop-ssh/authorized_keys/root")
    machine.succeed("systemctl restart sshd.service")
    machine.wait_for_unit("sshd.service")
    machine.fail(ssh + "root@100.64.0.1 true")
    machine.succeed("systemctl restart sshd.service")
    machine.wait_for_unit("sshd.service")
    machine.succeed(ssh + "rinyaresu@100.64.0.1 true")
    machine.succeed("chmod 0666 /var/lib/desktop-ssh/authorized_keys/rinyaresu")
    machine.fail(ssh + "rinyaresu@100.64.0.1 true")
    machine.succeed("chmod 0644 /var/lib/desktop-ssh/authorized_keys/rinyaresu; systemctl restart sshd.service")
    machine.wait_for_unit("sshd.service")
    machine.succeed(ssh + "rinyaresu@100.64.0.1 true")
    machine.succeed("rm /var/lib/desktop-ssh/authorized_keys/rinyaresu")
    machine.fail(ssh + "rinyaresu@100.64.0.1 true")
