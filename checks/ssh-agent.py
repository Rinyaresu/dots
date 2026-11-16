import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


openssh = Path(sys.argv[1]) / "bin"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    socket = root / "agent.sock"
    env = {**os.environ, "SSH_AUTH_SOCK": str(socket), "SSH_ASKPASS_REQUIRE": "force"}
    subprocess.run([str(openssh / "ssh-keygen"), "-q", "-t", "ed25519", "-N",
                    "fixture-passphrase", "-f", str(root / "key")], check=True)
    askpass = root / "askpass"
    askpass.write_text(f"#!{sys.executable}\n" + '''import os
from pathlib import Path
import sys
root = Path(os.environ["ASKPASS_TEST_ROOT"])
with (root / "prompts").open("a") as log:
    log.write("prompt\\n")
if (root / "cancel").exists():
    sys.exit(1)
print("fixture-passphrase")
''')
    askpass.chmod(0o755)
    env.update(SSH_ASKPASS=str(askpass), ASKPASS_TEST_ROOT=str(root))

    def add(*arguments):
        return subprocess.run([str(openssh / "ssh-add"), *arguments], env=env,
                              stdin=subprocess.DEVNULL, capture_output=True, timeout=4)

    assert add("-l").returncode == 2
    agent = subprocess.Popen([str(openssh / "ssh-agent"), "-D", "-a", str(socket)],
                             env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 4
        while not socket.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        assert add("-l").returncode == 1
        (root / "cancel").touch()
        assert add(str(root / "key")).returncode != 0
        assert add("-l").returncode == 1
        (root / "cancel").unlink()
        result = add(str(root / "key"))
        assert result.returncode == 0, result.stderr
        assert add("-l").returncode == 0
        assert add("-T", str(root / "key.pub")).returncode == 0
        assert add("-T", str(root / "key.pub")).returncode == 0
        assert (root / "prompts").read_text().splitlines() == ["prompt", "prompt"]
        assert add("-D").returncode == 0
        assert add("-l").returncode == 1
    finally:
        agent.terminate()
        agent.communicate(timeout=4)

print("PASS native agent unavailable, empty, cancel, encrypted identity unlock, repeated signing, manual removal")
