#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile


def export(root, destination):
    names = (root / 'source-files.txt').read_text().splitlines()
    if len(names) != len(set(names)):
        raise ValueError('Duplicate source paths')
    records = {}
    for name in names:
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or not relative.parts:
            raise ValueError(f'Invalid source path: {name}')
        allowed = name in {'flake.nix', 'flake.lock', 'source-files.txt',
                           'scripts/check', 'scripts/export-source.py',
                           '.githooks/pre-push'} or (
            relative.parts[0] in {'modules', 'checks'} and
            relative.suffix in {'.nix', '.py', '.patch', '.sh', '.fish'})
        if not allowed:
            raise ValueError(f'Path outside build inputs: {name}')
        source = root / name
        for parent in [source, *source.parents]:
            if parent == root:
                break
            if parent.is_symlink():
                raise ValueError(f'Symlink in source path: {name}')
        if not source.is_file():
            raise ValueError(f'Missing source file: {name}')
        data = source.read_bytes()
        records[name] = {'sha256': hashlib.sha256(data).hexdigest(),
                         'executable': bool(source.stat().st_mode & 0o111)}
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        shutil.copymode(source, target)
    return records


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    artifacts = state / 'pi/work-artifacts/nix'
    artifacts.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='check-source-', dir=artifacts))
    source = run / 'source'
    source.mkdir()
    records = export(root, source)
    (run / 'manifest.json').write_text(json.dumps(records, sort_keys=True, indent=2) + '\n')
    print(source)
