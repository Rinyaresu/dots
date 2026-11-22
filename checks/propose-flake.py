import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout.strip()


class Proposal(unittest.TestCase):
    def test_policy_block_and_retry_reuse_branch(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            base = root / "base"
            base.mkdir()
            run("git", "init", "-b", "master", str(base))
            (base / ".github").mkdir()
            script = ".github/propose-flake.sh"
            (base / script).write_text((ROOT / script).read_text())
            (base / "flake.nix").write_text('pi.url = "github:earendil-works/pi/stable";\n')
            (base / "flake.lock").write_text('{"root":"root","nodes":{"root":{"inputs":{"pi":"pi"}},"pi":{"rev":"old"}}}\n')
            run("git", "add", ".", cwd=base)
            run("git", "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "-m", "base", cwd=base)
            sha = run("git", "rev-parse", "HEAD", cwd=base)
            remote = root / "remote.git"
            run("git", "clone", "--bare", str(base), str(remote))
            bin_dir = root / "bin"
            bin_dir.mkdir()
            gh = bin_dir / "gh"
            gh.write_text('''#!/usr/bin/env bash
case "$*" in
  *git/ref/heads/master*) echo "$GITHUB_SHA" ;;
  *actions/permissions/workflow*) echo "$POLICY" ;;
  *"pr list"*) : ;;
  *"workflow run"*) echo dispatch >> "$LOG" ;;
  *"pr create"*) echo create >> "$LOG"; [[ "$CREATE" == ok ]] ;;
  *) echo "unexpected gh: $*" >&2; exit 1 ;;
esac
''')
            gh.chmod(0o755)
            nix = bin_dir / "nix"
            nix.write_text('''#!/usr/bin/env bash
[[ "$*" == 'flake update' ]] || exit 1
case "$UPDATE" in
  no-op) exit 0 ;;
  change-reference) echo 'unexpected change' >> flake.nix ;;
esac
python3 -c 'from pathlib import Path; p=Path("flake.lock"); p.write_text(p.read_text().replace("old", "new"))'
''')
            nix.chmod(0o755)
            env = os.environ | {
                "PATH": f"{bin_dir}:{os.environ['PATH']}", "EVENT": "schedule",
                "UPDATE": "normal", "ADVISORY": "", "GITHUB_SHA": sha,
                "GITHUB_REPOSITORY": "example/dots", "GITHUB_SERVER_URL": "https://github.com",
                "GITHUB_STEP_SUMMARY": str(root / "summary"), "LOG": str(root / "calls"),
            }

            def attempt(name, policy="true", create="ok", **overrides):
                checkout = root / name
                run("git", "clone", str(remote), str(checkout))
                return subprocess.run(["bash", script], cwd=checkout,
                                      env=env | {"POLICY": policy, "CREATE": create} | overrides,
                                      text=True, capture_output=True)

            no_op = attempt("no-op", UPDATE="no-op")
            self.assertEqual(no_op.returncode, 0, no_op.stderr)
            self.assertIn("No flake updates.", (root / "summary").read_text())
            changed_reference = attempt("change-reference", UPDATE="change-reference")
            self.assertNotEqual(changed_reference.returncode, 0)
            self.assertIn("diff --git a/flake.nix b/flake.nix", changed_reference.stdout)
            invalid_advisory = attempt("invalid-advisory", EVENT="workflow_dispatch", ADVISORY="invalid")
            self.assertNotEqual(invalid_advisory.returncode, 0)
            self.assertIn("Invalid advisory identifier", invalid_advisory.stderr)
            self.assertFalse((root / "calls").exists())

            blocked = attempt("blocked", "false", "fail")
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("no branch was pushed", blocked.stderr)
            self.assertEqual(run("git", "--git-dir", str(remote), "branch", "--list", "automation/*"), "")
            first = attempt("first", "true", "fail")
            self.assertNotEqual(first.returncode, 0, first.stderr)
            self.assertIn("PR creation failed", first.stderr)
            branches = run("git", "--git-dir", str(remote), "branch", "--list", "automation/*")
            self.assertEqual(len(branches.splitlines()), 1)
            self.assertEqual(run("git", "--git-dir", str(remote), "diff", "--name-only",
                                 sha, branches.strip()), "flake.lock")
            second = attempt("second")
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(run("git", "--git-dir", str(remote), "branch", "--list", "automation/*"), branches)
            self.assertEqual((root / "calls").read_text().splitlines(), ["dispatch", "create", "dispatch", "create"])


if __name__ == "__main__":
    unittest.main()
