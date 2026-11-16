import shlex


fixture = "/run/secret-runtime-fixture"
inputs = ("key.txt", "ssh.yaml")
secret = "/run/secrets/rinyaresu-ssh-key"
identity = "/home/rinyaresu/.ssh/id_ed25519"
sops_unit = "sops-install-secrets.service"
home_unit = "home-manager-rinyaresu.service"
passphrase = "disposable-secret-runtime-fixture-passphrase"


def as_user(user, command):
    return f"su -s /bin/sh {user} -c {shlex.quote(command)}"


def install_inputs():
    for name in inputs:
        machine.succeed(
            f"rm -f /var/lib/sops-nix/{name}; "
            f"install -m 0600 -o root -g root {fixture}/{name} /var/lib/sops-nix/{name}"
        )


def assert_refused():
    machine.succeed(f"systemctl reset-failed {sops_unit} {home_unit}")
    machine.fail(f"systemctl start {home_unit}")
    machine.succeed(f"systemctl is-failed --quiet {sops_unit}")
    machine.fail(f"systemctl is-active --quiet {home_unit}")
    machine.succeed(f"test ! -e {secret} && test ! -L {identity} && test ! -e {identity}")


machine.start()
machine.wait_for_unit("multi-user.target")
machine.wait_until_succeeds(f"systemctl is-failed --quiet {sops_unit}")

with subtest("Build and boot need neither private inputs nor a Home checkout"):
    machine.succeed(
        "test ! -e /var/lib/sops-nix/key.txt && "
        "test ! -e /var/lib/sops-nix/ssh.yaml && "
        "test ! -e /home/rinyaresu/personal/home && "
        "test ! -e /home/rinyaresu/.pi"
    )
    machine.fail("systemctl cat pi-config-restore.service")
    assert_refused()

with subtest("Generate disposable encrypted fixtures only inside the VM"):
    machine.succeed(f"install -d -m 0700 {fixture}")
    machine.succeed(f"umask 077; age-keygen -o {fixture}/key.txt")
    machine.succeed(f"umask 077; age-keygen -o {fixture}/wrong-key.txt")
    machine.succeed(
        f"ssh-keygen -q -t ed25519 -N {passphrase} "
        f"-C disposable-secret-runtime-fixture -f {fixture}/id_ed25519"
    )
    generator = (
        "import json, pathlib; "
        f"p = pathlib.Path({fixture!r}); "
        "(p / 'ssh.json').write_text(json.dumps("
        "{'ssh_private_key': (p / 'id_ed25519').read_text()}))"
    )
    machine.succeed(f"umask 077; python3 -c {shlex.quote(generator)}")
    machine.succeed(
        f"umask 077; sops --encrypt --input-type json --output-type yaml "
        f"--age \"$(age-keygen -y {fixture}/key.txt)\" "
        f"{fixture}/ssh.json > {fixture}/ssh.yaml"
    )

invalid_inputs = (
    ("missing", "rm {path}"),
    ("empty", "truncate -s 0 {path}"),
    ("readable by others", "chmod 0644 {path}"),
    ("read only instead of required 0600", "chmod 0400 {path}"),
    ("wrong owner", "chown rinyaresu {path}"),
    ("wrong group", "chgrp users {path}"),
    ("symlink", "rm {path}; ln -s {original} {path}"),
)
for name in inputs:
    for label, mutation in invalid_inputs:
        with subtest(f"Refuse {name} when {label} and keep Home Manager blocked"):
            install_inputs()
            machine.succeed(
                mutation.format(
                    path=f"/var/lib/sops-nix/{name}", original=f"{fixture}/{name}"
                )
            )
            assert_refused()

with subtest("Permissions alone cannot turn plaintext into a SOPS secret"):
    install_inputs()
    machine.succeed("printf 'ssh_private_key: not-encrypted\\n' > /var/lib/sops-nix/ssh.yaml")
    assert_refused()

with subtest("A different age identity cannot decrypt the fixture"):
    install_inputs()
    machine.succeed(
        f"install -m 0600 -o root -g root {fixture}/wrong-key.txt /var/lib/sops-nix/key.txt"
    )
    assert_refused()

with subtest("Valid external inputs unblock real SOPS and Home Manager"):
    install_inputs()
    machine.succeed(f"systemctl reset-failed {sops_unit} {home_unit}")
    machine.succeed(f"systemctl start {home_unit}")
    machine.wait_for_unit(sops_unit)
    machine.wait_for_unit(home_unit)
    assert machine.succeed(f"stat -Lc '%U:%G:%a' {secret}").strip() == "rinyaresu:users:600"
    assert (
        machine.succeed("stat -c '%U:%G:%a' /home/rinyaresu/.ssh").strip()
        == "rinyaresu:users:700"
    )
    machine.succeed(f"test -L {identity}")
    assert machine.succeed(f"readlink {identity}").strip().startswith("/nix/store/")
    resolved = machine.succeed(f"readlink -e {identity}").strip()
    assert resolved == machine.succeed(f"readlink -e {secret}").strip()
    assert resolved.startswith("/run/secrets.d/")
    machine.succeed(f"cmp {fixture}/id_ed25519 {secret}")
    machine.succeed(as_user("rinyaresu", f"test -r {identity}"))
    machine.fail(as_user("observer", f"test -r {secret}"))
    machine.fail(as_user("observer", f"test -r {identity}"))
    for name in inputs:
        machine.fail(as_user("rinyaresu", f"test -r /var/lib/sops-nix/{name}"))

with subtest("Provisioned identity retains its passphrase and fixture public key"):
    machine.fail(as_user("rinyaresu", f"ssh-keygen -y -P '' -f {identity}"))
    machine.fail(as_user("rinyaresu", f"ssh-keygen -y -P wrong-fixture-passphrase -f {identity}"))
    actual_public = machine.succeed(
        as_user("rinyaresu", f"ssh-keygen -y -P {passphrase} -f {identity}")
    ).split()[:2]
    expected_public = machine.succeed(f"cut -d ' ' -f 1,2 {fixture}/id_ed25519.pub").split()
    assert actual_public == expected_public

with subtest("Restarting provisioners keeps the same usable identity"):
    machine.succeed(f"systemctl restart {sops_unit}; systemctl restart {home_unit}")
    machine.succeed(f"cmp {fixture}/id_ed25519 {identity}")
    assert (
        machine.succeed(as_user("rinyaresu", f"ssh-keygen -y -P {passphrase} -f {identity}"))
        .split()[:2]
        == expected_public
    )
