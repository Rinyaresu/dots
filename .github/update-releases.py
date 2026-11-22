#!/usr/bin/env python3
import json
import re
import subprocess
import sys
from pathlib import Path

path = Path("flake.nix")
source = path.read_text()
projects = {"pi": "earendil-works/pi", "herdr": "herdrdev/herdr"}
if len(sys.argv) != 2 or sys.argv[1] not in projects:
    raise SystemExit("Usage: update-releases.py pi|herdr")
for name in (sys.argv[1],):
    repo = projects[name]
    pattern = rf'({name}\.url = "github:{re.escape(repo)}/)(v\d+\.\d+\.\d+)(";)'
    matches = list(re.finditer(pattern, source))
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one stable {name} reference")
    release = json.loads(subprocess.check_output(["gh", "api", "--method", "GET", f"repos/{repo}/releases/latest"]))
    tag = release["tag_name"]
    if release["draft"] or release["prerelease"] or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise SystemExit(f"Invalid stable release for {name}: {tag}")
    current = matches[0].group(2)
    version = lambda value: tuple(map(int, value[1:].split(".")))
    if version(tag) < version(current):
        raise SystemExit(f"Refusing to downgrade {name} from {current} to {tag}")
    source = source[:matches[0].start(2)] + tag + source[matches[0].end(2):]
    print(f"{name}: {current} -> {tag}")
path.write_text(source)
