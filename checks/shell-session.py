import os
from pathlib import Path
import pty
import subprocess
import sys
import tempfile


fish, init_path, function_path, herdr_binary = sys.argv[1:]
init = Path(init_path).read_text()
function = Path(function_path).read_text() if function_path != "-" else ""

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    stub = root / "herdr"
    stub.write_text(f"#!{sys.executable}\n" + '''import os
from pathlib import Path
import sys
Path(os.environ["HERDR_TEST_LOG"]).write_text("attached")
sys.exit(int(os.environ.get("HERDR_TEST_EXIT", "0")))
''')
    stub.chmod(0o755)
    init = init.replace(herdr_binary, str(stub))
    function = function.replace(herdr_binary, str(stub))
    startup = root / "startup.fish"
    startup.write_text(function + "\n" + init)

    def run(name, variables, interactive=True, succeeds=True, tty=True):
        log = root / (name + ".log")
        env = {"HOME": str(root), "XDG_CONFIG_HOME": str(root / "config"),
               "XDG_DATA_HOME": str(root / "data"), "XDG_CACHE_HOME": str(root / "cache"),
               "XDG_STATE_HOME": str(root / "state"), "PATH": str(root) + ":/usr/bin:/bin",
               "TERM": "xterm-256color", "HERDR_TEST_LOG": str(log), **variables}
        command = f"source '{startup}'; echo COMMON_SHELL"
        master, slave = pty.openpty()
        try:
            result = subprocess.run([fish, "--no-config", *(["-i"] if interactive else []),
                                     "-c", command], stdin=slave if tty else subprocess.DEVNULL, env=env,
                                    capture_output=True, text=True, timeout=8)
        finally:
            os.close(slave)
            os.close(master)
        assert result.returncode == 0, (name, result.stdout, result.stderr)
        assert log.exists() == succeeds, (name, result.stdout, result.stderr)
        return result.stdout

    assert "COMMON_SHELL" in run("wayland", {"WAYLAND_DISPLAY": "wayland-1"})
    assert "COMMON_SHELL" in run("x11", {"DISPLAY": ":0"})
    for name, env in [
        ("console", {}),
        ("nested", {"DISPLAY": ":0", "HERDR_ENV": "1"}),
        ("pane", {"DISPLAY": ":0", "HERDR_PANE_ID": "fixture"}),
        ("tmux", {"DISPLAY": ":0", "TMUX": "/tmp/tmux-test/default,42,0"}),
        ("ssh", {"DISPLAY": ":10", "SSH_CONNECTION": "fixture"}),
        ("ssh-tty", {"DISPLAY": ":10", "SSH_TTY": "/dev/pts/1"}),
        ("opt-out", {"DISPLAY": ":0", "HERDR_NO_AUTO": "1"}),
    ]:
        assert "COMMON_SHELL" in run(name, env, succeeds=False)
    assert "COMMON_SHELL" in run("script", {"DISPLAY": ":0"}, interactive=False, succeeds=False)
    assert "COMMON_SHELL" in run("no-tty", {"DISPLAY": ":0"}, succeeds=False, tty=False)
    assert "COMMON_SHELL" in run("failure", {"DISPLAY": ":0", "HERDR_TEST_EXIT": "1"})

print("PASS graphical attach, console, script, SSH, nested pane, tmux, opt-out, failed attach fallback")
