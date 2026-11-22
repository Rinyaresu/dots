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
    def run_update(self, lane="pi", tag="v1.6.0", prerelease=False, source=SOURCE):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "flake.nix").write_text(source)
            gh = root / "gh"
            gh.write_text('#!/bin/sh\nprintf "%s" "$RELEASE"\n')
            gh.chmod(0o755)
            env = os.environ | {
                "PATH": f"{root}:{os.environ['PATH']}",
                "RELEASE": json.dumps({"tag_name": tag, "draft": False, "prerelease": prerelease}),
            }
            result = subprocess.run(["python3", str(SCRIPT), lane], cwd=root, env=env, capture_output=True, text=True)
            return result, (root / "flake.nix").read_text()

    def test_updates_only_selected_reference(self):
        result, content = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pi/v1.6.0", content)
        self.assertIn("herdr/v0.9.5", content)
        result, content = self.run_update(lane="herdr", tag="v0.9.6")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pi/v1.5.0", content)
        self.assertIn("herdr/v0.9.6", content)

    def test_rejects_downgrade_and_prerelease_without_write(self):
        for kwargs in ({"tag": "v1.4.9"}, {"prerelease": True}, {"tag": "v1.6.0-rc.1"}):
            with self.subTest(kwargs=kwargs):
                result, content = self.run_update(**kwargs)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(content, SOURCE)

    def test_rejects_unexpected_reference_or_lane(self):
        for kwargs in ({"source": SOURCE.replace("v1.5.0", "main")}, {"lane": "general"}):
            result, content = self.run_update(**kwargs)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(content, kwargs.get("source", SOURCE))


if __name__ == "__main__":
    unittest.main()
