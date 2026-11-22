import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / ".github/update-releases.py"
SOURCE = '''pi.url = "github:earendil-works/pi/v1.5.0";
herdr.url = "github:herdrdev/herdr/v0.9.5";
'''


class ReleaseUpdates(unittest.TestCase):
    def run_update(self, pi="v1.6.0", herdr="v0.9.5", prerelease=False, source=SOURCE):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "flake.nix").write_text(source)
            gh = root / "gh"
            gh.write_text("#!/bin/sh\ncase \"$*\" in *earendil*) printf '%s' \"$PI_RELEASE\";; *) printf '%s' \"$HERDR_RELEASE\";; esac\n")
            gh.chmod(0o755)
            env = os.environ | {
                "PATH": f"{root}:{os.environ['PATH']}",
                "PI_RELEASE": json.dumps({"tag_name": pi, "draft": False, "prerelease": prerelease}),
                "HERDR_RELEASE": json.dumps({"tag_name": herdr, "draft": False, "prerelease": False}),
            }
            result = subprocess.run(["python3", str(SCRIPT)], cwd=root, env=env, capture_output=True, text=True)
            return result, (root / "flake.nix").read_text()

    def test_updates_both_references(self):
        result, content = self.run_update(herdr="v0.9.6")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pi/v1.6.0", content)
        self.assertIn("herdr/v0.9.6", content)

    def test_rejects_downgrade_and_prerelease_without_partial_write(self):
        for kwargs in ({"herdr": "v0.9.4"}, {"prerelease": True}, {"pi": "v1.6.0-rc.1"}):
            with self.subTest(kwargs=kwargs):
                result, content = self.run_update(**kwargs)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(content, SOURCE)

    def test_rejects_unexpected_reference(self):
        result, content = self.run_update(source=SOURCE.replace("v1.5.0", "main"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("/main", content)


if __name__ == "__main__":
    unittest.main()
