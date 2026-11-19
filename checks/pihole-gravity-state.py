"""Capture durable gravity state without checkpointing the live database."""
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile


def digest_file(path):
    if not path.is_file():
        return None
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def logical(path, require_marker=False):
    conn = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    try:
        conn.execute('PRAGMA query_only = ON')
        conn.execute('BEGIN')
        journal, = conn.execute('PRAGMA journal_mode').fetchone()
        assert conn.execute('PRAGMA integrity_check').fetchall() == [('ok',)]
        if require_marker:
            assert conn.execute(
                "SELECT comment FROM domainlist WHERE domain = 'persist.fixture.example.com'"
            ).fetchall() == [('persistence-marker',)]
        # Sort dump statements so row traversal order does not mask equality.
        statement_digest = hashlib.sha256(
            json.dumps(sorted(conn.iterdump())).encode()
        ).hexdigest()
        return {
            'journal': journal,
            'schema_version': conn.execute('PRAGMA schema_version').fetchone()[0],
            'user_version': conn.execute('PRAGMA user_version').fetchone()[0],
            'application_id': conn.execute('PRAGMA application_id').fetchone()[0],
            'dump': statement_digest,
        }
    finally:
        conn.close()


def snapshot():
    state = Path('/var/lib/pihole')
    db = state / 'gravity.db'
    result = logical(db, require_marker=True)
    for p in sorted(state.glob('gravity*.db')):
        if p != db:
            result.setdefault('other-gravity', {})[p.name] = logical(p)
    # Covers persistent files used by gravity besides SQLite; no sessions or logs.
    for pattern in ('list.*', 'adlists.list', 'gravity.list', 'gravity*.db_temp', 'gravity_temp*'):
        for p in sorted(state.glob(pattern)):
            if p.is_file():
                result.setdefault('aux', {})[p.name] = digest_file(p)
    return result


def check_wal_fixture():
    with tempfile.TemporaryDirectory() as folder:
        db = Path(folder) / 'fixture.db'
        writer = sqlite3.connect(db)
        try:
            assert writer.execute('PRAGMA journal_mode = WAL').fetchone() == ('wal',)
            writer.execute('PRAGMA wal_autocheckpoint = 0')
            writer.execute('CREATE TABLE example (value TEXT)')
            writer.commit()
            writer.execute('PRAGMA wal_checkpoint(TRUNCATE)').fetchone()
            original_file = digest_file(db)
            original_view = logical(db)
            writer.execute("INSERT INTO example VALUES ('wal-only change')")
            writer.commit()
            assert digest_file(db) == original_file
            assert db.with_name('fixture.db-wal').stat().st_size > 0
            assert logical(db)['dump'] != original_view['dump']
        finally:
            writer.close()


mode, record = sys.argv[1:]
if mode == 'before':
    check_wal_fixture()
    print('GRAVITY WAL fixture: logical change detected with main file unchanged')
    current = snapshot()
    Path(record).write_text(json.dumps(current, sort_keys=True))
    print(f"GRAVITY before: journal={current['journal']} marker=present integrity=ok")
elif mode == 'after':
    before = json.loads(Path(record).read_text())
    current = snapshot()
    assert before == current, 'durable gravity state changed after setup refusal'
    print(f"GRAVITY after: journal={current['journal']} marker=present integrity=ok "
          'logical-and-auxiliary=unchanged')
else:
    raise ValueError(mode)
