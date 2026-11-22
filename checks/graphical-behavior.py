import argparse
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import tempfile
import tomllib
import unittest


parser = argparse.ArgumentParser()
parser.add_argument("--capture", required=True)
parser.add_argument("--lock", required=True)
parser.add_argument("--session", required=True)
parser.add_argument("--noctalia", required=True)
parser.add_argument("--satty")
parser.add_argument("--tools", required=True)
args = parser.parse_args()
tools = json.loads(Path(args.tools).read_text())
satty_config = args.satty or re.search(r"--config\s+(\S+)", Path(args.capture).read_text())[1]


class GraphicalTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.env = os.environ | {
            "HOME": str(self.home),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "EVENTS": str(self.root / "events"),
            "CLIPBOARD": str(self.root / "clipboard"),
            "RELEASE": str(self.root / "release"),
        }
        Path(self.env["CLIPBOARD"]).write_bytes(b"previous clipboard")
        self.stub("slurp", 'printf "10,20 300x200\\n"')
        self.stub("grim", 'printf original > "$3"')
        self.stub("satty", 'printf edited > "$6"')
        self.stub("wl-copy", 'printf "%s\\n" "$*" >> "$EVENTS"; cat > "$CLIPBOARD"')
        self.stub("dunstctl", 'printf "%s\\n" "$*" >> "$EVENTS"')
        self.stub("i3lock", 'printf "locked\\n" >> "$EVENTS"')
        for name in ("systemctl", "dbus-update-activation-environment", "xset", "xsetroot"):
            self.stub(name, f'printf "%s|%s|%s|%s|%s\\n" "{name}" "$*" "${{DISPLAY-}}" "${{WAYLAND_DISPLAY-}}" "${{XAUTHORITY-}}" >> "$EVENTS"')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!" + shutil.which("bash") + "\nset -eu\n" + body + "\n")
        path.chmod(0o700)

    def script(self, source, name):
        text = Path(source).read_text()
        for tool, original in tools.items():
            text = text.replace(original, str(self.bin / tool))
        destination = self.root / name
        destination.write_text(text)
        return destination

    def capture(self):
        return subprocess.run(
            ["bash", str(self.script(args.capture, "capture"))],
            env=self.env,
            capture_output=True,
            timeout=5,
        )

    def screenshots(self):
        return list(self.home.glob("Pictures/Screenshots/*.png"))

    def assert_unpublished(self):
        self.assertEqual(self.screenshots(), [])
        self.assertEqual(Path(self.env["CLIPBOARD"]).read_bytes(), b"previous clipboard")
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_selection_cancel_publishes_nothing(self):
        self.stub("slurp", "exit 1")
        self.assertEqual(self.capture().returncode, 0)
        self.assert_unpublished()
        self.assertFalse((self.home / "Pictures").exists())

    def test_empty_selection_publishes_nothing(self):
        self.stub("slurp", "exit 0")
        self.assertEqual(self.capture().returncode, 0)
        self.assert_unpublished()

    def test_capture_failure_publishes_nothing(self):
        self.stub("grim", "exit 23")
        self.assertNotEqual(self.capture().returncode, 0)
        self.assert_unpublished()

    def test_editor_cancel_publishes_nothing(self):
        self.stub("satty", "exit 0")
        self.assertEqual(self.capture().returncode, 0)
        self.assert_unpublished()

    def test_editor_failure_publishes_nothing(self):
        self.stub("satty", 'printf edited > "$6"; exit 24')
        self.assertNotEqual(self.capture().returncode, 0)
        self.assert_unpublished()

    def test_confirm_saves_and_copies_edited_image_without_overwrite(self):
        for _ in range(2):
            result = self.capture()
            self.assertEqual(result.returncode, 0, result.stderr.decode())
        files = self.screenshots()
        self.assertEqual(len(files), 2)
        for path in files:
            self.assertEqual(path.read_bytes(), b"edited")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(self.env["CLIPBOARD"]).read_bytes(), b"edited")
        self.assertEqual((self.root / "events").read_text().splitlines(), ["--type image/png"] * 2)
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_satty_uses_explicit_commit_and_escape_only_exits(self):
        general = tomllib.loads(Path(satty_config).read_text())["general"]
        self.assertTrue(general["early-exit"])
        self.assertEqual(general["actions-on-enter"], ["save-to-file"])
        self.assertEqual(general["actions-on-right-click"], ["save-to-file"])
        self.assertEqual(general["actions-on-escape"], ["exit"])
        self.assertEqual(Path(general["copy-command"]).name, "true")

    def test_noctalia_locks_then_powers_off_without_suspend(self):
        config = tomllib.loads(Path(args.noctalia).read_text())
        behavior = config["idle"]["behavior"]
        self.assertEqual(behavior["lock"], {"enabled": True, "timeout": 600, "action": "lock"})
        self.assertEqual(behavior["screen-off"], {"enabled": True, "timeout": 900, "action": "screen_off"})
        self.assertFalse(behavior["suspend"]["enabled"])
        self.assertTrue(config["lockscreen"]["enabled"])
        self.assertTrue(config["lockscreen"]["lock_before_suspend"])
        self.assertEqual(config["nightlight"]["temperature_day"], 5900)
        self.assertEqual(config["nightlight"]["temperature_night"], 2600)
        self.assertTrue(config["nightlight"]["enabled"])
        self.assertFalse(config["nightlight"]["force"])
        self.assertTrue(config["location"]["custom_schedule"])
        self.assertEqual(config["theme"]["mode"], "light")

    def test_noctalia_uses_secret_service_for_up_to_100_clipboard_entries(self):
        config = tomllib.loads(Path(args.noctalia).read_text())
        self.assertEqual(config["storage"]["key_source"], "secret-service")
        self.assertTrue(config["shell"]["clipboard_enabled"])
        self.assertEqual(config["shell"]["clipboard_history_max_entries"], 100)

    def test_noctalia_uses_the_official_wallpaper_without_rotation(self):
        config = tomllib.loads(Path(args.noctalia).read_text())
        wallpaper = config["wallpaper"]
        path = Path(wallpaper["default"]["path"])
        self.assertTrue(wallpaper["enabled"])
        self.assertFalse(wallpaper["automation"]["enabled"])
        self.assertEqual(path.name, "nix-wallpaper-simple-blue.png")
        self.assertTrue(path.is_file())

    def test_i3_preserves_sleep_inhibitor_until_locker_ready(self):
        self.stub("i3lock", '''
        eval "test -e /dev/fd/$XSS_SLEEP_LOCK_FD"
        printf 'inherited-inhibitor\n' >> "$EVENTS"
        eval "exec $XSS_SLEEP_LOCK_FD>&-"
        while [ ! -e "$RELEASE" ]; do sleep 0.01; done
        printf 'unlocked\n' >> "$EVENTS"
        ''')
        read_fd, write_fd = os.pipe()
        self.addCleanup(os.close, read_fd)
        process = subprocess.Popen(
            ["bash", str(self.script(args.lock, "lock"))],
            env=self.env | {"XSS_SLEEP_LOCK_FD": str(write_fd)},
            pass_fds=(write_fd,),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        os.close(write_fd)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        ready, _, _ = select.select([read_fd], [], [], 5)
        self.assertTrue(ready, "locker did not release the sleep inhibitor")
        self.assertEqual(os.read(read_fd, 1), b"")
        self.assertIsNone(process.poll(), "wrapper exited while the locker was active")
        events = (self.root / "events").read_text().splitlines()
        self.assertEqual(events, ["set-paused true", "inherited-inhibitor"])
        Path(self.env["RELEASE"]).touch()
        _, error = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, error.decode())
        self.assertEqual((self.root / "events").read_text().splitlines(), events + ["unlocked", "set-paused false"])

    def test_startx_imports_graphical_environment_without_replacing_ssh_agent(self):
        source = self.script(args.session, "session")
        with source.open("a") as script:
            script.write('\n[[ "$XDG_CURRENT_DESKTOP" == i3 && "$XDG_SESSION_TYPE" == x11 ]]\n')
            script.write('[[ -z "${WAYLAND_DISPLAY-}" && "$SSH_AUTH_SOCK" == /runtime/ssh-agent ]]\n')
        result = subprocess.run(
            ["bash", str(source)],
            env=self.env | {
                "DISPLAY": ":7",
                "XAUTHORITY": "/runtime/xauthority",
                "WAYLAND_DISPLAY": "stale-wayland",
                "XDG_SESSION_ID": "7",
                "SSH_AUTH_SOCK": "/runtime/ssh-agent",
            },
            capture_output=True,
            timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        events = (self.root / "events").read_text().splitlines()
        imports = [line for line in events if "--systemd" in line]
        self.assertEqual(len(imports), 1)
        self.assertIn("DISPLAY XAUTHORITY XDG_SESSION_ID", imports[0])
        self.assertTrue(imports[0].endswith("|:7||/runtime/xauthority"))
        self.assertIn("xset|dpms 0 0 900|:7||/runtime/xauthority", events)
        cleanup = [line for line in events if "unset-environment DISPLAY" in line]
        self.assertEqual(len(cleanup), 1)
        self.assertTrue(all("SSH_AUTH_SOCK" not in line for line in events))


unittest.main(argv=[__file__], verbosity=2)
