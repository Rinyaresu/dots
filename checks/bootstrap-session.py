import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


script = Path(sys.argv[1]).read_text()
packages = dict(arg.split("=", 1) for arg in sys.argv[2:])
openssh = Path(packages["ssh-add"]) / "bin"


def wait_for(predicate, process, label):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if predicate():
            return
        if process.poll() is not None:
            output = process.communicate()[0]
            raise AssertionError(f"{label}: restore exited with {process.returncode}: {output}")
        time.sleep(0.01)
    raise AssertionError(f"{label}: timed out")


def lines(path):
    return path.read_text().splitlines() if path.exists() else []


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    keys = root / "keys"
    keys.mkdir()
    for name, password in (("required", "fixture-passphrase"), ("unrelated", "")):
        subprocess.run([str(openssh / "ssh-keygen"), "-q", "-t", "ed25519", "-N", password,
                        "-C", name, "-f", str(keys / name)], check=True)
    stubs = root / "stubs"
    stubs.mkdir()
    commands = {
        "askpass": '''import os
from pathlib import Path
import sys
root = Path(os.environ["TEST_ROOT"])
assert os.environ["SSH_ASKPASS_REQUIRE"] == "force"
assert os.environ.get("WAYLAND_DISPLAY") == "wayland-test"
assert os.environ.get("XAUTHORITY") == "/tmp/authority with spaces"
assert "UNRELATED" not in os.environ
assert str(Path(os.environ["HOME"]) / ".ssh/id_ed25519") in sys.argv[1]
with (root / "prompts").open("a") as log:
    log.write("prompt\\n")
if (root / "cancel").exists():
    sys.exit(1)
print("fixture-passphrase")
''',
        "preload": 'print("fixture-passphrase")\n',
        "systemctl": '''import os
from pathlib import Path
root = Path(os.environ["TEST_ROOT"])
if (root / "graphical").exists():
    print("WAYLAND_DISPLAY=wayland-test")
    print("XAUTHORITY=/tmp/authority with spaces")
print("UNRELATED=do-not-import")
''',
        "git": '''import os
from pathlib import Path
import subprocess
import sys
root = Path(os.environ["TEST_ROOT"])
assert os.environ["SSH_AUTH_SOCK"] == str(root / "ssh-agent")
assert os.environ["GIT_TERMINAL_PROMPT"] == "0"
assert "BatchMode=yes" in os.environ["GIT_SSH_COMMAND"]
assert "StrictHostKeyChecking=yes" in os.environ["GIT_SSH_COMMAND"]
assert "ForwardAgent=no" in os.environ["GIT_SSH_COMMAND"]
assert sys.argv[1:4] == ["clone", "--single-branch", "--branch"]
assert sys.argv[4] == "main"
assert not (Path(os.environ["HOME"]) / ".ssh/id_ed25519.pub").exists()
subprocess.run([os.environ["TEST_SSH_ADD"], "-T", os.environ["TEST_PUBLIC_KEY"]],
               check=True, capture_output=True)
repository, destination = sys.argv[5:7]
with (root / "clones").open("a") as log:
    log.write(repository + "\\n")
destination = Path(destination)
destination.mkdir()
if repository.endswith("/home.git"):
    (destination / "references").mkdir()
    (destination / "references/personal.md").write_text("instructions")
else:
    assert (Path(os.environ["HOME"]) / "personal/home/references/personal.md").is_file()
(destination / "clone-complete").write_text("complete")
''',
        "sleep": '''import os
from pathlib import Path
import time
with (Path(os.environ["TEST_ROOT"]) / "polls").open("a") as log:
    log.write("poll\\n")
time.sleep(0.03)
''',
    }
    for name, body in commands.items():
        path = stubs / name
        path.write_text(f"#!{sys.executable}\n" + body)
        path.chmod(0o755)
    for name in ("git", "systemctl", "sleep"):
        script = script.replace(f"{packages[name]}/bin/{name}", str(stubs / name))
    restore = root / "restore"
    restore.write_text(script)
    restore.chmod(0o755)

    class Session:
        def __init__(self, name, available=True, graphical=False, cancel=False, loaded=()):
            self.case = root / name
            self.home = self.case / "home"
            (self.home / ".ssh").mkdir(parents=True)
            shutil.copyfile(keys / "required", self.home / ".ssh/id_ed25519")
            (self.home / ".ssh/id_ed25519").chmod(0o600)
            if graphical:
                (self.case / "graphical").touch()
            if cancel:
                (self.case / "cancel").touch()
            self.env = {key: value for key, value in os.environ.items()
                        if key not in {"DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "SSH_AGENT_PID"}}
            self.env.update(HOME=str(self.home), TEST_ROOT=str(self.case),
                            SSH_AUTH_SOCK=str(self.case / "ssh-agent"),
                            SSH_ASKPASS=str(stubs / "askpass"), SSH_ASKPASS_REQUIRE="force",
                            TEST_SSH_ADD=str(openssh / "ssh-add"),
                            TEST_PUBLIC_KEY=str(keys / "required.pub"))
            self.agent = None
            self.process = None
            if available:
                self.start_agent()
            for identity in loaded:
                self.add(identity)

        def start_agent(self):
            self.agent = subprocess.Popen(
                [str(openssh / "ssh-agent"), "-D", "-a", self.env["SSH_AUTH_SOCK"]],
                env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            wait_for(lambda: Path(self.env["SSH_AUTH_SOCK"]).is_socket(), self.agent, "agent socket")

        def add(self, identity):
            subprocess.run([str(openssh / "ssh-add"), str(keys / identity)],
                           env={**self.env, "SSH_ASKPASS": str(stubs / "preload")},
                           stdin=subprocess.DEVNULL, capture_output=True, check=True, timeout=8)

        def __enter__(self):
            self.process = subprocess.Popen([str(restore)], env=self.env, stdout=subprocess.PIPE,
                                            stderr=subprocess.STDOUT, text=True)
            return self

        def __exit__(self, *_):
            if self.process.poll() is None:
                self.process.terminate()
            self.process.communicate(timeout=8)
            if self.agent:
                self.agent.terminate()
                self.agent.wait(timeout=8)

        def waiting(self):
            previous = len(lines(self.case / "polls"))
            wait_for(lambda: len(lines(self.case / "polls")) >= previous + 3,
                     self.process, "restore remains waiting")
            assert not (self.case / "clones").exists()

        def restored(self, prompts):
            output = self.process.communicate(timeout=8)[0]
            assert self.process.returncode == 0, output
            assert lines(self.case / "clones") == [
                "git@github.com:Rinyaresu/home.git", "git@github.com:Rinyaresu/agent.git"]
            assert (self.home / ".pi/clone-complete").exists()
            assert lines(self.case / "prompts") == ["prompt"] * prompts

    with Session("unavailable", available=False, graphical=True) as session:
        session.waiting()
        assert not (session.case / "prompts").exists()
        session.start_agent()
        session.restored(prompts=1)
        second = subprocess.run([str(restore)], env={**os.environ, "HOME": str(session.home)},
                                capture_output=True, text=True, timeout=8)
        assert second.returncode == 0, second.stdout + second.stderr
        assert len(lines(session.case / "clones")) == 2
    print("PASS unavailable agent, empty agent, graphical unlock, ordered clones, repeat")

    with Session("cancelled", graphical=True, cancel=True) as session:
        wait_for(lambda: (session.case / "prompts").exists(), session.process, "cancel prompt")
        session.waiting()
        assert lines(session.case / "prompts") == ["prompt"]
        session.add("unrelated")
        session.waiting()
        assert lines(session.case / "prompts") == ["prompt"]
        session.add("required")
        session.restored(prompts=1)
    print("PASS cancellation once, unrelated identity still waits, later external unlock")

    with Session("console-then-graphical") as session:
        session.waiting()
        assert not (session.case / "prompts").exists()
        (session.case / "graphical").touch()
        session.restored(prompts=1)
    print("PASS console waits for graphical environment")

    with Session("unrelated-loaded", graphical=True, loaded=("unrelated",)) as session:
        session.restored(prompts=1)
        identities = subprocess.run([str(openssh / "ssh-add"), "-l"], env=session.env,
                                    capture_output=True, text=True, check=True).stdout.splitlines()
        assert len(identities) == 2
    print("PASS unrelated identity triggers required-key askpass and both identities remain loaded")

    with Session("required-loaded", graphical=True, loaded=("required",)) as session:
        session.restored(prompts=0)
    print("PASS required identity already loaded, no duplicate prompt")

    with Session("both-loaded", graphical=True, loaded=("unrelated", "required")) as session:
        session.restored(prompts=0)
    print("PASS two identities already loaded, no duplicate prompt")
