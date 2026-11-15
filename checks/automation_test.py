import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AutomationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='nix-check-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ['scripts', '.githooks', 'checks', 'modules', 'bin']:
            (self.root / directory).mkdir()
        for relative in ['scripts/check', '.githooks/pre-push']:
            shutil.copy2(ROOT / relative, self.root / relative)
        (self.root / 'checks/fixture_test.py').write_text(
            'import unittest\nclass Fixture(unittest.TestCase):\n'
            '    def test_fixture(self):\n        self.assertTrue(True)\n')
        (self.root / 'flake.nix').write_text('{}\n')
        (self.root / 'modules/with space.nix').write_text('{}\n')
        self.trace = self.root / 'trace.jsonl'
        nix = self.root / 'bin/nix'
        nix.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['TRACE'], 'a') as stream:
    stream.write(json.dumps({'cwd': os.getcwd(), 'args': sys.argv[1:],
                             'git_dir': os.environ.get('GIT_DIR')}) + '\\n')
stage = 'formatter' if 'run' in sys.argv else 'check'
sys.exit(1 if os.environ.get('FAIL_STAGE') == stage else 0)
''')
        nix.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        TRACE=str(self.trace))

    def run_check(self, *arguments, failure=''):
        return subprocess.run([str(self.root / 'scripts/check'), *arguments],
                              cwd='/', env=dict(self.env, FAIL_STAGE=failure),
                              capture_output=True, text=True)

    def calls(self):
        if not self.trace.exists():
            return []
        return [json.loads(line) for line in self.trace.read_text().splitlines()]

    def test_full_runs_formatter_and_builds_checks_from_repository_root(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        formatter, check = self.calls()
        self.assertEqual(formatter['cwd'], str(self.root))
        self.assertIn('modules/with space.nix', formatter['args'])
        self.assertIn('--check', formatter['args'])
        self.assertIn('check', check['args'])
        self.assertNotIn('--no-build', check['args'])
        for call in [formatter, check]:
            self.assertIn('--no-write-lock-file', call['args'])

    def test_quick_evaluates_without_building(self):
        result = self.run_check('--quick')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--no-build', self.calls()[-1]['args'])

    def test_invalid_arguments_do_not_run_nix(self):
        for arguments in [('--typo',), ('',), ('--quick', '--quick')]:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_check(*arguments).returncode, 2)
                self.assertEqual(self.calls(), [])

    def test_formatter_failure_stops_before_flake_check(self):
        self.assertNotEqual(self.run_check(failure='formatter').returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_builder_failure_is_not_reported_as_success(self):
        self.assertNotEqual(self.run_check(failure='check').returncode, 0)
        self.assertEqual(len(self.calls()), 2)

    def test_git_invokes_pre_push_and_propagates_failure(self):
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'config', '--local',
                        'core.hooksPath', '.githooks'], check=True)
        for failure in ['', 'check']:
            with self.subTest(failure=failure):
                result = subprocess.run(['git', '-C', str(self.root), 'hook', 'run',
                                         'pre-push'], env=dict(self.env, FAIL_STAGE=failure,
                                                              GIT_DIR=str(self.root / '.git'),
                                                              GIT_WORK_TREE=str(self.root)),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, not failure, result.stderr)
                self.assertIn('--no-build', self.calls()[-1]['args'])
                self.assertIsNone(self.calls()[-1]['git_dir'])


if __name__ == '__main__':
    unittest.main()
