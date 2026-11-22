import argparse
import fnmatch
import os
from pathlib import Path
import stat
import subprocess
import sys


EDITOR_ARTIFACTS = ("*.swp", "*.swo", ".DS_Store")
TEMP_ARTIFACTS = ("*.pid", "*.log")
DUMP_PATTERN = "*-dump-*-raw.sql"


def file_identity(metadata):
    return (metadata.st_dev, metadata.st_ino, metadata.st_size,
            metadata.st_mtime_ns, metadata.st_ctime_ns)


def unlink_checked(home, path, identity):
    # Anchor traversal to HOME and refuse symlinked parents after confirmation.
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    descriptor = os.open(home, flags)
    try:
        for part in path.relative_to(home).parts[:-1]:
            child = os.open(part, flags, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        metadata = os.stat(path.name, dir_fd=descriptor, follow_symlinks=False)
        if not stat.S_ISREG(metadata.st_mode) or file_identity(metadata) != identity:
            raise ValueError(f"Candidate changed during cleanup: {os.fspath(path)!r}")
        os.unlink(path.name, dir_fd=descriptor)
    finally:
        os.close(descriptor)


def scan_error(error):
    raise error


def plan_cleanup(roots):
    candidates = {}
    latest = {}
    for root in roots:
        try:
            mode = root.lstat().st_mode
        except FileNotFoundError:
            continue
        if not stat.S_ISDIR(mode) or root.resolve() != root:
            raise ValueError(f"Invalid cleanup root: {root}")
        for parent, dirs, files in os.walk(root, onerror=scan_error):
            parent = Path(parent)
            relative = parent.relative_to(root).parts
            # Each immediate child of the cleanup root is a separate project.
            # Do not traverse assets or Git internals, even if a name matches.
            dirs[:] = [name for name in dirs if name not in {"public", ".git"}]
            if not relative or relative[0].startswith("."):
                continue
            project = root / relative[0]
            inside = relative[1:]
            cache = inside[:2] == ("node_modules", ".cache")
            if "node_modules" in inside and not cache:
                continue
            temporary = cache or inside[:1] in {("tmp",), (".cache",)}
            for name in files:
                path = parent / name
                metadata = path.lstat()
                if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
                    continue
                identity = file_identity(metadata)
                if fnmatch.fnmatchcase(name, DUMP_PATTERN):
                    group = (project, name.split("-dump-", 1)[0])
                    newest_time = latest.get(group, metadata.st_mtime_ns)
                    latest[group] = max(newest_time, metadata.st_mtime_ns)
                    candidates[path] = (DUMP_PATTERN, identity, group)
                    continue
                for pattern in EDITOR_ARTIFACTS + (TEMP_ARTIFACTS if temporary else ()):
                    if fnmatch.fnmatchcase(name, pattern):
                        candidates[path] = (pattern, identity, None)
                        break
    # Preserve all ties rather than guessing which backup to keep.
    return {path: (kind, identity) for path, (kind, identity, group) in sorted(candidates.items())
            if group is None or identity[3] < latest[group]}


def human_size(value):
    return subprocess.check_output(["numfmt", "--to=iec", "--suffix=B", str(value)], text=True).strip()


def show_plan(plan):
    totals = {}
    print("The following files/directories will be removed:")
    for path, (kind, identity) in plan.items():
        space = identity[2]
        totals[kind] = totals.get(kind, 0) + space
        display = os.fspath(path)
        if not display.isprintable():
            display = repr(display)
        print(f"  [{human_size(space)}] {display}")
    print("\nSummary by type:")
    for kind, space in sorted(totals.items()):
        print(f"  [{human_size(space)}] {kind}")
    print(f"\nTotal space to be freed: {human_size(sum(totals.values()))}\n")


def main():
    parser = argparse.ArgumentParser(description="Preview cleanup and keep the newest dump of each set.")
    parser.add_argument("--dry-run", action="store_true", help="show the plan without asking to delete")
    args = parser.parse_args()
    home = Path.home().resolve(strict=True)
    roots = [home / "personal"]
    print("Scanning for files/directories to clean (dry-run)...")
    plan = plan_cleanup(roots)
    if not plan:
        print("No files or directories found for cleanup.")
        return 0
    show_plan(plan)
    if args.dry_run:
        return 0
    try:
        answer = input("Do you really want to delete all the items above? (y/N): ")
    except EOFError:
        answer = ""
    if answer not in {"y", "Y"}:
        print("Nothing was removed.")
        return 0
    if plan_cleanup(roots) != plan:
        raise ValueError("The cleanup plan changed. Nothing was removed. Inspect it again before continuing.")
    for path, (_, identity) in plan.items():
        unlink_checked(home, path, identity)
        print(f"Removed: {os.fspath(path)!r}")
    print("Cleanup completed!")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, AttributeError, TypeError, subprocess.CalledProcessError) as error:
        sys.exit(f"Cleanup stopped: {error}")
