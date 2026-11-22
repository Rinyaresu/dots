import argparse
import fnmatch
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys


DIR_TYPES = {"tmp", "log", ".cache", "public"}
FILE_TYPES = ("*.pid", "*.swp", "*.swo", "*.DS_Store", "*.log", "*-dump-*-raw.sql")
DUMP_PATTERN = FILE_TYPES[-1]


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
            for name in dirs:
                path = parent / name
                if path.is_symlink():
                    continue
                if name in DIR_TYPES and len(relative) < 2:
                    candidates[path] = name
                if name == ".cache" and relative[-1:] == ("node_modules",) and len(relative) < 3:
                    candidates[path] = "node_modules/.cache"
            for name in files:
                path = parent / name
                if not stat.S_ISREG(path.lstat().st_mode):
                    continue
                if fnmatch.fnmatchcase(name, DUMP_PATTERN):
                    group = (root, name.split("-dump-", 1)[0])
                    newer = (os.fsencode(name), path)
                    if group not in latest or newer > latest[group]:
                        latest[group] = newer
                if "node_modules" in relative:
                    continue
                for pattern in FILE_TYPES:
                    if fnmatch.fnmatchcase(name, pattern):
                        candidates[path] = pattern
                        break
    for _, dump in latest.values():
        candidates.pop(dump, None)
        for parent in dump.parents:
            candidates.pop(parent, None)
    return {path: candidates[path] for path in sorted(candidates)
            if not any(parent in candidates for parent in path.parents)}


def size(path):
    if path.is_dir():
        result = subprocess.check_output(["du", "-sb", "--", path])
        return int(result.split(b"\t", 1)[0])
    return path.stat().st_size


def human_size(value):
    return subprocess.check_output(["numfmt", "--to=iec", "--suffix=B", str(value)], text=True).strip()


def show_plan(plan):
    totals = {}
    print("The following files/directories will be removed:")
    for path, kind in plan.items():
        space = size(path)
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
    roots = [Path.home().resolve(strict=True) / "personal"]
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
    for path in plan:
        if stat.S_ISDIR(path.lstat().st_mode):
            shutil.rmtree(path)
        else:
            path.unlink()
        print(f"Removed: {os.fspath(path)!r}")
    print("Cleanup completed!")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, AttributeError, TypeError, subprocess.CalledProcessError) as error:
        sys.exit(f"Cleanup stopped: {error}")
