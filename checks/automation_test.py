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
        for directory in ['scripts', '.githooks', 'checks', 'modules', 'secrets', 'bin']:
            (self.root / directory).mkdir()
        for relative in ['scripts/check', 'scripts/export-source.py', '.githooks/pre-push']:
            shutil.copy2(ROOT / relative, self.root / relative)
        (self.root / 'checks/fixture_test.py').write_text(
            'import unittest\nclass Fixture(unittest.TestCase):\n'
            '    def test_fixture(self):\n        self.assertTrue(True)\n')
        (self.root / 'flake.nix').write_text('{}\n')
        (self.root / 'flake.lock').write_text('{}\n')
        (self.root / 'modules/with space.nix').write_text('{}\n')
        (self.root / 'plan.md').write_text('private planning fixture\n')
        (self.root / 'modules/backup.nix').write_text('private backup fixture\n')
        (self.root / 'secrets/ssh.yaml').write_text(
            'ssh_private_key: ENC[AES256_GCM,data:Zml4dHVyZQ==,'
            'iv:aXY=,tag:dGFn,type:str]\nsops:\n    version: fixture\n')
        (self.root / 'secrets/other.yaml').write_text('private fixture\n')
        (self.root / 'secrets/key.txt').write_text('private fixture\n')
        (self.root / 'source-files.txt').write_text('\n'.join([
            'flake.nix', 'flake.lock', 'scripts/check', 'scripts/export-source.py',
            '.githooks/pre-push', 'checks/fixture_test.py',
            'modules/with space.nix', 'secrets/ssh.yaml', 'source-files.txt']) + '\n')
        self.trace = self.root / 'trace.jsonl'
        nix = self.root / 'bin/nix'
        nix.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['TRACE'], 'a') as stream:
    stream.write(json.dumps({'cwd': os.getcwd(), 'args': sys.argv[1:],
                             'files': sorted(str(p.relative_to(os.getcwd()))
                                 for p in __import__('pathlib').Path.cwd().rglob('*')
                                 if p.is_file()),
                             'git_dir': os.environ.get('GIT_DIR')}) + '\\n')
stage = 'formatter' if 'run' in sys.argv else 'check'
sys.exit(1 if os.environ.get('FAIL_STAGE') == stage else 0)
''')
        nix.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        TRACE=str(self.trace), XDG_STATE_HOME=str(self.root / 'state'))

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
        self.assertNotEqual(formatter['cwd'], str(self.root))
        self.assertTrue(Path(formatter['cwd']).parent.joinpath('manifest.json').is_file())
        self.assertEqual(formatter['cwd'], check['cwd'])
        for call in [formatter, check]:
            self.assertNotIn('plan.md', call['files'])
            self.assertNotIn('modules/backup.nix', call['files'])
            self.assertIn('modules/with space.nix', call['files'])
            self.assertIn('secrets/ssh.yaml', call['files'])
            self.assertNotIn('secrets/other.yaml', call['files'])
            self.assertNotIn('secrets/key.txt', call['files'])
        self.assertIn('modules/with space.nix', formatter['args'])
        self.assertIn('--check', formatter['args'])
        self.assertIn('check', check['args'])
        self.assertNotIn('--no-build', check['args'])
        for call in [formatter, check]:
            self.assertIn('--no-write-lock-file', call['args'])

    def test_success_reports_each_phase(self):
        result = self.run_check('--quick')
        self.assertEqual(result.returncode, 0, result.stderr)
        for phase in ['export', 'python', 'formatter', 'nix-checks']:
            self.assertRegex(result.stdout,
                             rf'CI phase={phase} elapsed_seconds=\d+ status=0')

    def test_quick_evaluates_without_building(self):
        result = self.run_check('--quick')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--no-build', self.calls()[-1]['args'])

    def test_plaintext_in_approved_path_stops_before_nix(self):
        (self.root / 'secrets/ssh.yaml').write_text('ssh_private_key: plaintext-fixture\n')
        result = self.run_check('--quick')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SOPS ciphertext envelope', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_unapproved_yaml_stops_before_nix(self):
        with (self.root / 'source-files.txt').open('a') as stream:
            stream.write('secrets/other.yaml\n')
        result = self.run_check('--quick')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Path outside build inputs', result.stderr)
        self.assertEqual(self.calls(), [])

    def test_invalid_arguments_do_not_run_nix(self):
        for arguments in [('--typo',), ('',), ('--quick', '--quick')]:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_check(*arguments).returncode, 2)
                self.assertEqual(self.calls(), [])

    def test_formatter_failure_stops_before_flake_check(self):
        result = self.run_check(failure='formatter')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.calls()), 1)
        self.assertRegex(result.stderr, r'CI phase=formatter elapsed_seconds=\d+ status=123')
        self.assertNotIn('CI phase=formatter', result.stdout)
        self.assertNotIn('CI phase=nix-checks', result.stdout)

    def test_builder_failure_is_not_reported_as_success(self):
        result = self.run_check(failure='check')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.calls()), 2)
        self.assertRegex(result.stderr, r'CI phase=nix-checks elapsed_seconds=\d+ status=1')
        self.assertNotIn('CI phase=nix-checks', result.stdout)

    def test_python_failure_stops_before_nix(self):
        (self.root / 'checks/fixture_test.py').write_text(
            'import unittest\nclass Fixture(unittest.TestCase):\n'
            '    def test_fixture(self):\n        self.fail("fixture failure")\n')
        result = self.run_check('--quick')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertRegex(result.stderr, r'CI phase=python elapsed_seconds=\d+ status=1')

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
