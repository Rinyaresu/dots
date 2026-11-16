import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('source_export', ROOT / 'scripts/export-source.py')
source_export = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source_export)


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / 'repository'
        self.destination = Path(self.temporary.name) / 'source'
        self.root.mkdir()
        self.destination.mkdir()
        (self.root / 'flake.nix').write_text('current uncommitted bytes\n')
        (self.root / 'plan.md').write_text('private fixture\n')
        (self.root / 'source-files.txt').write_text('flake.nix\nsource-files.txt\n')

    def test_only_explicit_files_and_current_bytes_are_exported(self):
        records = source_export.export(self.root, self.destination)
        self.assertEqual(set(records), {'flake.nix', 'source-files.txt'})
        self.assertEqual((self.destination / 'flake.nix').read_text(),
                         'current uncommitted bytes\n')
        self.assertFalse((self.destination / 'plan.md').exists())
        self.assertEqual(len(records['flake.nix']['sha256']), 64)

    def test_only_approved_ciphertext_path_is_exported(self):
        (self.root / 'secrets').mkdir()
        ciphertext = (b'ssh_private_key: ENC[AES256_GCM,data:Zml4dHVyZQ==,'
                      b'iv:aXY=,tag:dGFn,type:str]\nsops:\n    version: fixture\n')
        (self.root / 'secrets/ssh.yaml').write_bytes(ciphertext)
        (self.root / 'secrets/other.yaml').write_text('private fixture\n')
        (self.root / 'secrets/key.txt').write_text('private fixture\n')
        (self.root / 'source-files.txt').write_text('secrets/ssh.yaml\n')
        records = source_export.export(self.root, self.destination)
        self.assertEqual(set(records), {'secrets/ssh.yaml'})
        self.assertEqual((self.destination / 'secrets/ssh.yaml').read_bytes(), ciphertext)
        self.assertFalse((self.destination / 'secrets/other.yaml').exists())
        self.assertFalse((self.destination / 'secrets/key.txt').exists())

    def test_approved_path_rejects_plaintext_mixed_data_and_private_identity(self):
        (self.root / 'secrets').mkdir()
        (self.root / 'source-files.txt').write_text('secrets/ssh.yaml\n')
        envelope = ('ssh_private_key: ENC[AES256_GCM,data:Zml4dHVyZQ==,'
                    'iv:aXY=,tag:dGFn,type:str]\nsops:\n    version: fixture\n')
        for content in ['', 'ssh_private_key: plaintext-fixture\n',
                        'AGE-SECRET-KEY-DISPOSABLE-NOT-A-KEY\n',
                        '-----BEGIN OPENSSH PRIVATE KEY-----\nfixture\n',
                        envelope + 'extra: plaintext-fixture\n',
                        envelope + '    identity: AGE-SECRET-KEY-FIXTURE\n',
                        envelope + '    identity: -----BEGIN OPENSSH PRIVATE KEY-----\n']:
            with self.subTest(content=content):
                (self.root / 'secrets/ssh.yaml').write_text(content)
                with self.assertRaisesRegex(ValueError, 'SOPS ciphertext envelope'):
                    source_export.export(self.root, self.destination)
                self.assertFalse((self.destination / 'secrets/ssh.yaml').exists())

    def test_other_yaml_and_private_paths_are_rejected_even_when_listed(self):
        for name in ['secrets/other.yaml', 'secrets/ssh.yml', 'secrets/nested/ssh.yaml',
                     'modules/ssh.yaml', 'checks/ssh.yaml', 'ssh.yaml',
                     'secrets/key.txt', 'secrets/id_ed25519', 'secrets/vpn.conf']:
            with self.subTest(name=name):
                source = self.root / name
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_text('private fixture\n')
                (self.root / 'source-files.txt').write_text(name + '\n')
                with self.assertRaisesRegex(ValueError, 'Path outside build inputs'):
                    source_export.export(self.root, self.destination)

    def test_approved_ciphertext_cannot_be_a_symlink(self):
        (self.root / 'secrets').mkdir()
        (self.root / 'secrets/ssh.yaml').symlink_to(self.root / 'plan.md')
        (self.root / 'source-files.txt').write_text('secrets/ssh.yaml\n')
        with self.assertRaisesRegex(ValueError, 'Symlink in source path'):
            source_export.export(self.root, self.destination)
        (self.root / 'secrets/ssh.yaml').unlink()
        (self.root / 'secrets').rmdir()
        (self.root / 'secrets').symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink in source path'):
            source_export.export(self.root, self.destination)

    def test_private_paths_parent_traversal_and_duplicates_are_rejected(self):
        for paths in ['plan.md\n', '../plan.md\n', '/etc/passwd\n',
                      'flake.nix\nflake.nix\n', 'modules/missing.nix\n']:
            with self.subTest(paths=paths):
                (self.root / 'source-files.txt').write_text(paths)
                with self.assertRaises(ValueError):
                    source_export.export(self.root, self.destination)

    def test_symlinks_and_symlinked_parents_are_rejected(self):
        outside = Path(self.temporary.name) / 'outside'
        outside.mkdir()
        (outside / 'secret.nix').write_text('private fixture\n')
        (self.root / 'modules').symlink_to(outside, target_is_directory=True)
        (self.root / 'source-files.txt').write_text('modules/secret.nix\n')
        with self.assertRaises(ValueError):
            source_export.export(self.root, self.destination)
        (self.root / 'modules').unlink()
        (self.root / 'flake.nix').unlink()
        (self.root / 'flake.nix').symlink_to(outside / 'secret.nix')
        (self.root / 'source-files.txt').write_text('flake.nix\n')
        with self.assertRaises(ValueError):
            source_export.export(self.root, self.destination)


if __name__ == '__main__':
    unittest.main()
