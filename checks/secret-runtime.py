import json
import shlex


fixture = "/run/secret-runtime-fixture"
age_identity = "/var/lib/sops-nix/key.txt"
secret = "/run/secrets/rinyaresu-ssh-key"
identity = "/home/rinyaresu/.ssh/id_ed25519"
sops_unit = "sops-install-secrets.service"
home_unit = "home-manager-rinyaresu.service"
passphrase = "disposable-secret-runtime-fixture-passphrase"


def as_user(user, command):
    return f"su -s /bin/sh {user} -c {shlex.quote(command)}"


def install_identity():
    machine.succeed(
        f"rm -f {age_identity}; "
        f"install -m 0600 -o root -g root {fixture}/key.txt {age_identity}"
    )


def mount_ciphertext(name="ssh.yaml"):
    machine.succeed(
        f"chmod 0644 {fixture}/{name}; "
        f"if mountpoint -q {ciphertext}; then umount {ciphertext}; fi; "
        f"mount --bind {fixture}/{name} {ciphertext}; "
        f"mount -o remount,bind,ro {ciphertext}"
    )
    machine.succeed(f"mountpoint -q {ciphertext}")
    machine.fail(f"printf forbidden >> {ciphertext}")


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

manifest = json.loads(machine.succeed("cat /etc/secret-runtime-manifest.json"))
assert len(manifest["secrets"]) == 1
ciphertext = manifest["secrets"][0]["sopsFile"]
assert ciphertext.startswith("/nix/store/")
assert manifest["ageKeyFile"] == age_identity

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
mount_ciphertext()
for label, mutation in invalid_inputs:
    with subtest(f"Refuse age identity when {label} and keep Home Manager blocked"):
        install_identity()
        machine.succeed(mutation.format(path=age_identity, original=f"{fixture}/key.txt"))
        assert_refused()

with subtest("The declared ciphertext path rejects an unencrypted document"):
    install_identity()
    machine.succeed(f"printf 'ssh_private_key: not-encrypted\\n' > {fixture}/invalid.yaml")
    mount_ciphertext("invalid.yaml")
    assert_refused()

with subtest("A different age identity cannot decrypt the declared ciphertext"):
    mount_ciphertext()
    install_identity()
    machine.succeed(
        f"install -m 0600 -o root -g root {fixture}/wrong-key.txt {age_identity}"
    )
    assert_refused()

with subtest("The legacy runtime ciphertext cannot override the declared source"):
    machine.succeed(
        f"install -m 0600 -o root -g root {fixture}/ssh.yaml /var/lib/sops-nix/ssh.yaml"
    )
    install_identity()
    mount_ciphertext("invalid.yaml")
    assert_refused()
    machine.succeed("rm /var/lib/sops-nix/ssh.yaml")

with subtest("Declared store ciphertext unblocks real SOPS and Home Manager"):
    mount_ciphertext()
    install_identity()
    machine.succeed("test ! -e /var/lib/sops-nix/ssh.yaml")
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
    machine.fail(as_user("rinyaresu", f"test -r {age_identity}"))
    machine.fail(as_user("observer", f"test -r {age_identity}"))
    machine.succeed(as_user("rinyaresu", f"test -r {ciphertext}"))
    machine.succeed(as_user("observer", f"test -r {ciphertext}"))

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

with subtest("Runtime fixture private bytes never enter the VM store"):
    scanner = r'''
import hashlib
import os
from pathlib import Path
import stat

fixture = Path('/run/secret-runtime-fixture')
age = (fixture / 'key.txt').read_bytes()
ssh = (fixture / 'id_ed25519').read_bytes()
age_line = next(line for line in age.splitlines() if line.startswith(b'AGE-SECRET-KEY-'))
needles = (age, age_line, ssh, ssh.strip())
assert all(needles)
keep = max(map(len, needles)) - 1
required = {
    str(Path('/etc/secret-runtime-manifest.json').resolve()),
    str(Path('/etc/secret-runtime-activation/activate').resolve()),
    str(Path('/etc/secret-runtime-source/secrets/ssh.yaml').resolve()),
}
import json
manifest = json.loads(Path('/etc/secret-runtime-manifest.json').read_text())
required.add(manifest['secrets'][0]['sopsFile'])
seen = set()
count = 0
for directory, _, files in os.walk('/nix/store', followlinks=False):
    for name in files:
        path = Path(directory) / name
        if not stat.S_ISREG(path.lstat().st_mode):
            continue
        tail = b''
        with path.open('rb') as stream:
            while chunk := stream.read(1024 * 1024):
                block = tail + chunk
                assert not any(needle in block for needle in needles), 'private fixture bytes in store'
                tail = block[-keep:]
        seen.add(str(path))
        count += 1
assert required <= seen, 'required source, manifest, activation or ciphertext not scanned'
print('PASS exact private fixture bytes absent from', count, 'regular store files')
print('PASS fixture digests', hashlib.sha256(age).hexdigest(), hashlib.sha256(ssh).hexdigest())
'''
    print(machine.succeed(f"python3 -c {shlex.quote(scanner)}", timeout=180))
