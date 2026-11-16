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
