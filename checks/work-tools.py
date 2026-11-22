import os
from pathlib import Path
import subprocess
import sys
import tempfile

(clean,) = sys.argv[1:]
with tempfile.TemporaryDirectory() as directory:
    home = Path(directory)
    env = {**os.environ, "HOME": directory}
    workspace = home / "workspace"
    paths = {
        "personal/project/tmp/app-dump-2-raw.sql": True,
        "personal/project/tmp/app-dump-1-raw.sql": False,
        "personal/project/tmp/service.log": False,
        "personal/project/.cache/cache.log": False,
        "personal/project/public/only-dump-1-raw.sql": True,
        "personal/project/public/site.log": True,
        "personal/project/public/assets/test.pid": True,
        "personal/project/tmp/important.txt": True,
        "personal/project/log/application.log": True,
        "personal/other/tmp/app-dump-0-raw.sql": True,
        "personal/other/tmp/app-dump-9-raw.sql": False,
        "personal/other/tmp/app-dump-tied-raw.sql": True,
        "personal/project/node_modules/.cache/stale.log": False,
        "personal/project/node_modules/package/untouched.log": True,
        "personal/project/tmp/file\nname.pid": False,
        "personal/project/live.txt": True,
        "workspace/project/app-dump-1-raw.sql": True,
        "workspace/project/app-dump-0-raw.sql": True,
    }
    for name in paths:
        path = home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture")
    for name, timestamp in {
        "project/tmp/app-dump-2-raw.sql": 40,
        "project/tmp/app-dump-1-raw.sql": 30,
        "other/tmp/app-dump-0-raw.sql": 20,
        "other/tmp/app-dump-9-raw.sql": 10,
        "other/tmp/app-dump-tied-raw.sql": 20,
    }.items():
        os.utime(home / "personal" / name, (timestamp, timestamp))
    (home / "personal/project/tmp/external").symlink_to(workspace, target_is_directory=True)
    def run(command, answer=None, **variables):
        return subprocess.run(command, input=answer, env=env | variables, text=True, capture_output=True, timeout=10)

    preview = run([clean, "--dry-run"])
    assert preview.returncode == 0, preview.stderr
    assert "Summary by type:" in preview.stdout and "Total space to be freed:" in preview.stdout
    assert str(home / "personal/project/.cache/cache.log") in preview.stdout
    for protected in ("app-dump-2-raw.sql", "app-dump-0-raw.sql", "app-dump-tied-raw.sql",
                      "site.log", "test.pid", "important.txt", "application.log"):
        assert protected not in preview.stdout, protected
    assert "app-dump-1-raw.sql" in preview.stdout and "only-dump-1-raw.sql" not in preview.stdout
    assert "Nothing was removed." in run([clean], "n\n").stdout
    assert all((home / name).exists() for name in paths)
    race_dir = home / "personal/project/tmp/race"
    race_dir.mkdir()
    race = race_dir / "race-dump-1-raw.sql"
    race.write_text("retained during confirmation")
    candidate = race_dir / "race.log"
    candidate.write_text("candidate")
    proc = subprocess.Popen([clean], env=env, text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    marker = "(y/N): "
    output = ""
    while not output.endswith(marker):
        piece = proc.stdout.read(1)
        assert piece, output
        output = (output + piece)[-len(marker):]
    race.rename(race_dir / "race.log-dump-2-raw.sql")
    new_dump = home / "personal/project/.cache/new-dump-1-raw.sql"
    new_dump.write_text("new protected dump")
    candidate.write_text("changed after the preview")
    _, error = proc.communicate("y\n", timeout=10)
    assert proc.returncode != 0 and "The cleanup plan changed" in error
    assert new_dump.is_file() and candidate.is_file()
    new_dump.unlink()
    result = run([clean], "y\n")
    assert result.returncode == 0, result.stderr
    for name, protected in paths.items():
        assert (home / name).exists() == protected, (name, result.stdout, result.stderr)
    assert (home / "personal/project/tmp/external").is_symlink()
    print("PASS preview, decline, changed candidate, project-scoped retention, ties and protected assets")
