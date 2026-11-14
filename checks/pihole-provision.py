"""Exercise the shipped interactive provisioner inside the test VM only."""
import json
import os
from pathlib import Path
import pty
import select
import secrets


def provision(password, confirmation):
    pid, fd = pty.fork()
    if pid == 0:
        os.execlp("pihole-admin-hash", "pihole-admin-hash")
    pending = [b"New Pi-hole admin password: ", b"Confirm password: "]
    answers = [password, confirmation]
    transcript = b""
    while True:
        if not select.select([fd], [], [], 30)[0]:
            os.kill(pid, 9)
            raise AssertionError("Provisioner timed out")
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        transcript += chunk
        if pending and pending[0] in transcript:
            pending.pop(0)
            os.write(fd, answers.pop(0).encode() + b"\n")
            transcript = b""
    os.close(fd)
    return os.waitpid(pid, 0)[1]


secret = Path("/var/lib/pihole-secrets/admin-hash")
assert provision("", "") != 0
assert not secret.exists()
assert provision("mismatch-one", "mismatch-two") != 0
assert not secret.exists()
password = secrets.token_urlsafe(32)
assert provision(password, password) == 0
first = secret.read_text()
assert first.startswith("$BALLOON-SHA256$")
assert password not in first
assert provision("mismatch-one", "mismatch-two") != 0
assert secret.read_text() == first
# Rotation must replace an existing credential, without exposing its password.
password = secrets.token_urlsafe(32)
assert provision(password, password) == 0
assert secret.read_text() != first
Path("/run/test-auth.json").write_text(json.dumps({"password": password}))
os.chmod("/run/test-auth.json", 0o600)
print("Interactive provisioning, rejection, atomic preservation and rotation passed")
