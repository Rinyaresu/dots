import json
import shlex
import time


fixture = "/run/bootstrap-runtime-fixture"
home = "/home/rinyaresu"
identity = f"{home}/.ssh/id_ed25519"
passphrase = "disposable-bootstrap-passphrase"
restore_unit = "pi-config-restore.service"


def as_user(command):
    environment = (
        "export XDG_RUNTIME_DIR=/run/user/1000 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
        "SSH_AUTH_SOCK=/run/user/1000/ssh-agent; "
    )
    return f"su -s /bin/sh rinyaresu -c {shlex.quote(environment + command)}"


def userctl(command):
    return as_user(f"systemctl --user {command}")


# Exercise the production Pi loader with disposable state and no account settings.
def load_local_extensions(version):
    return as_user(
        'set -eu; scratch=$(mktemp -d); trap \'rm -rf -- "$scratch"\' EXIT; '
        'pi_bin=$(realpath "$(command -v pi)"); '
        'env -i HOME="$scratch" PATH="$PATH" PI_CODING_AGENT_DIR="$scratch" PI_OFFLINE=1 '
        f'PI_FIXTURE_VERSION={shlex.quote(version)} '
        'node /etc/bootstrap-pi-imports.mjs "$pi_bin" "$HOME/.pi/agent" "$scratch"'
    )


def wait_for_restore():
    machine.wait_until_succeeds(
        userctl(f"show -p ActiveState -p Result {restore_unit}")
        + " | grep -E '^(ActiveState=inactive|Result=success)$' | wc -l | grep -qx 2",
        timeout=90,
    )


machine.start()
machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("sshd.service")
machine.succeed(
    'ip -4 route flush default && ip -6 route flush default && '
    'test -z "$(ip -4 route show default)" && test -z "$(ip -6 route show default)"'
)
machine.wait_until_succeeds("systemctl is-failed --quiet sops-install-secrets.service")

with subtest("Generate all private fixtures only inside the disposable VM"):
    machine.succeed(f"install -d -m 0700 {fixture}")
    machine.succeed(f"umask 077; age-keygen -o {fixture}/key.txt")
    machine.succeed(
        f"ssh-keygen -q -t ed25519 -N {passphrase} -C bootstrap-required "
        f"-f {fixture}/id_ed25519"
    )
    machine.succeed(
        f"ssh-keygen -q -t ed25519 -N '' -C bootstrap-unrelated -f {fixture}/unrelated"
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

with subtest("Real local Git repositories and SSH accept only the SOPS fixture key"):
    for name in ("home", "agent"):
        working = f"{fixture}/{name}"
        machine.succeed(f"git init -q -b main {working}")
        if name == "home":
            machine.succeed(
                f"mkdir -p {working}/references; "
                f"printf 'fixture-home-instructions\\n' > {working}/references/personal.md"
            )
        else:
            machine.succeed(
                f"printf 'fixture-agent-config\\n' > {working}/fixture-config; "
                "npm_config_offline=true bash /etc/bootstrap-dependency-fixture.sh "
                f"{working}/agent/extensions/herdr-codemode /run/bootstrap-npm-fixture"
            )
        machine.succeed(
            f"git -C {working} add .; "
            f"git -C {working} -c user.name=Fixture -c user.email=fixture@example.invalid "
            f"commit -qm fixture; git clone -q --bare {working} /srv/git/{name}.git"
        )
    server = '''#!/bin/sh
set -eu
printf '%s\\n' "$SSH_ORIGINAL_COMMAND" >> /srv/git/requests
case "$SSH_ORIGINAL_COMMAND" in
  "git-upload-pack '/srv/git/home.git'"|"git-upload-pack '/srv/git/agent.git'")
    exec /bin/sh -c "$SSH_ORIGINAL_COMMAND" ;;
  *) exit 1 ;;
esac
'''
    machine.succeed(f"printf %s {shlex.quote(server)} > /srv/git/serve; chmod 0755 /srv/git/serve")
    machine.succeed("install -d -m 0700 /srv/git/.ssh")
    machine.succeed(
        "printf 'restrict,command=\"/srv/git/serve\" ' > /srv/git/.ssh/authorized_keys; "
        f"cat {fixture}/id_ed25519.pub >> /srv/git/.ssh/authorized_keys; "
        "chmod 0600 /srv/git/.ssh/authorized_keys; chown -R fixturegit:users /srv/git"
    )

with subtest("Real SOPS and Home Manager provision the encrypted SSH identity"):
    manifest = json.loads(machine.succeed("cat /etc/bootstrap-runtime-manifest.json"))
    assert len(manifest["secrets"]) == 1
    ciphertext = manifest["secrets"][0]["sopsFile"]
    assert ciphertext.startswith("/nix/store/")
    machine.succeed(
        f"chmod 0644 {fixture}/ssh.yaml; mount --bind {fixture}/ssh.yaml {ciphertext}; "
        f"mount -o remount,bind,ro {ciphertext}"
    )
    machine.fail(f"printf forbidden >> {ciphertext}")
    machine.succeed(
        f"install -m 0600 -o root -g root {fixture}/key.txt /var/lib/sops-nix/key.txt; "
        "test ! -e /var/lib/sops-nix/ssh.yaml; "
        "systemctl reset-failed sops-install-secrets.service home-manager-rinyaresu.service; "
        "systemctl start home-manager-rinyaresu.service"
    )
    machine.wait_for_unit("home-manager-rinyaresu.service")
    machine.succeed(f"test -L {identity} && cmp {fixture}/id_ed25519 {identity}")
    assert machine.succeed(f"stat -Lc '%U:%G:%a' {identity}").strip() == "rinyaresu:users:600"
    machine.fail(as_user(f"ssh-keygen -y -P '' -f {identity}"))
    machine.succeed(
        "awk '{ print \"localhost \" $1 \" \" $2 }' /etc/ssh/ssh_host_ed25519_key.pub "
        f"> {home}/.ssh/known_hosts; chown rinyaresu:users {home}/.ssh/known_hosts; "
        f"chmod 0600 {home}/.ssh/known_hosts; "
        f"install -m 0600 -o rinyaresu -g users {fixture}/unrelated {home}/unrelated"
    )
    machine.succeed(as_user(
        'git config --global url."ssh://fixturegit@localhost/srv/git/".insteadOf '
        'git@github.com:Rinyaresu/'
    ))

with subtest("The native agent with only an unrelated identity cannot restore either repository"):
    machine.succeed("systemctl start user@1000.service")
    machine.wait_until_succeeds("test -S /run/user/1000/ssh-agent")
    machine.succeed(userctl("unset-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY"))
    machine.succeed(as_user(f"ssh-add -D; ssh-add {home}/unrelated"))
    identities = machine.succeed(as_user("ssh-add -l")).splitlines()
    assert len(identities) == 1 and "bootstrap-unrelated" in identities[0]
    machine.succeed(userctl(f"is-enabled --quiet {restore_unit}"))
    machine.succeed(userctl("is-active --quiet pi-config-restore.path"))
    machine.wait_until_succeeds(userctl(f"is-active --quiet {restore_unit}"))
    time.sleep(11)
    machine.succeed(userctl(f"is-active --quiet {restore_unit}"))
    machine.succeed(
        f"test ! -e {home}/personal/home && test ! -e {home}/.pi && "
        f"test ! -e {home}/bootstrap-prompts && test ! -e /srv/git/requests"
    )

with subtest("Graphical login starts automatic restore; an npm failure is logged and retried"):
    tarball = "/run/bootstrap-npm-fixture/bootstrap-dep-1.0.0.tgz"
    extension = f"{home}/.pi/agent/extensions/herdr-codemode"
    machine.succeed(f"mv {tarball} {tarball}.unavailable")
    machine.succeed(userctl("set-environment DISPLAY=:fixture"))
    machine.wait_until_succeeds(
        as_user(f"journalctl --user -u {restore_unit} --no-pager") + " | grep -F 'npm ci falhou'",
        timeout=60,
    )
    machine.succeed(f"test ! -e {extension}/node_modules && mv {tarball}.unavailable {tarball}")
    # No restart: systemd must retry the failed install itself.
    machine.wait_until_succeeds(f"test -f {extension}/node_modules/.dots-dependencies.json", timeout=90)
    wait_for_restore()
    assert machine.succeed(f"cat {home}/personal/home/references/personal.md").strip() == "fixture-home-instructions"
    assert machine.succeed(f"cat {home}/.pi/fixture-config").strip() == "fixture-agent-config"
    requests = machine.succeed("cat /srv/git/requests").splitlines()
    assert requests == [
        "git-upload-pack '/srv/git/home.git'",
        "git-upload-pack '/srv/git/agent.git'",
    ]
    assert machine.succeed(f"wc -l < {home}/bootstrap-prompts").strip() == "1"
    identities = machine.succeed(as_user("ssh-add -l")).splitlines()
    assert len(identities) == 2
    required_fingerprint = machine.succeed(f"ssh-keygen -lf {fixture}/id_ed25519.pub").split()[1]
    assert any(required_fingerprint in line for line in identities)
    machine.succeed("systemctl is-active --quiet sops-install-secrets.service")
    machine.succeed("systemctl is-active --quiet home-manager-rinyaresu.service")
    machine.succeed(as_user('test -x "$(command -v efibootmgr)" && pi --version'))
    assert "1 extensões locais carregadas" in machine.succeed(load_local_extensions("1.0.0"))

with subtest("Repetition preserves both repositories, local edits and the unlocked identity"):
    machine.succeed(as_user(
        "printf 'local-home-edit\\n' >> ~/personal/home/references/personal.md; "
        "printf 'local-agent-edit\\n' >> ~/.pi/fixture-config"
    ))
    before = machine.succeed(
        as_user("git -C ~/personal/home rev-parse HEAD; git -C ~/.pi rev-parse HEAD")
    )
    old_inode = machine.succeed(f"stat -c %i {extension}/node_modules").strip()
    machine.succeed(userctl(f"start {restore_unit}"))
    wait_for_restore()
    assert machine.succeed("cat /srv/git/requests").splitlines() == requests
    assert machine.succeed(f"wc -l < {home}/bootstrap-prompts").strip() == "1"
    assert machine.succeed(
        as_user("git -C ~/personal/home rev-parse HEAD; git -C ~/.pi rev-parse HEAD")
    ) == before
    machine.succeed(as_user(
        "grep -qx local-home-edit ~/personal/home/references/personal.md && "
        "grep -qx local-agent-edit ~/.pi/fixture-config && ssh-add -l"
    ))
    assert machine.succeed(f"stat -c %i {extension}/node_modules").strip() == old_inode
    machine.succeed(load_local_extensions("1.0.0"))

with subtest("A Git fast-forward triggers reconciliation and failed updates retry automatically"):
    working = f"{fixture}/agent"
    tarball_v2 = "/run/bootstrap-npm-fixture/bootstrap-dep-2.0.0.tgz"
    machine.succeed(
        "npm_config_offline=true bash /etc/bootstrap-dependency-fixture.sh "
        f"{working}/agent/extensions/herdr-codemode /run/bootstrap-npm-fixture 2.0.0; "
        f"mv {tarball_v2} {tarball_v2}.unavailable; "
        f"git -C {working} add .; "
        f"git -C {working} -c user.name=Fixture -c user.email=fixture@example.invalid "
        f"commit -qm 'Update extension lock'; "
        f"git -C {working} push --receive-pack='git -c safe.directory=/srv/git/agent.git receive-pack' "
        "/srv/git/agent.git main"
    )
    machine.succeed(as_user("git -C ~/.pi pull --ff-only"))
    machine.wait_until_succeeds(
        as_user(f"journalctl --user -u {restore_unit} --no-pager") + " | grep -F 'bootstrap-dep-2.0.0.tgz'",
        timeout=60,
    )
    assert machine.succeed(f"stat -c %i {extension}/node_modules").strip() == old_inode
    machine.succeed(load_local_extensions("1.0.0"))
    machine.succeed(f"mv {tarball_v2}.unavailable {tarball_v2}")
    machine.wait_until_succeeds(
        f"grep -F 'version = \"2.0.0\"' {extension}/node_modules/bootstrap-dep/index.js",
        timeout=90,
    )
    wait_for_restore()
    machine.succeed(load_local_extensions("2.0.0"))
    machine.succeed(as_user("grep -qx local-agent-edit ~/.pi/fixture-config"))
    backup = f"{home}/.local/state/pi-extension-deps/transaction.*/node_modules"
    assert machine.succeed(f"stat -c %i {backup}").strip() == old_inode

with subtest("Pi loader rejects missing dependencies even after successful restore"):
    machine.succeed(as_user(
        "mv ~/.pi/agent/extensions/herdr-codemode/node_modules ~/saved-node-modules"
    ))
    assert "Cannot find module 'bootstrap-dep'" in machine.fail(load_local_extensions("2.0.0") + " 2>&1")
