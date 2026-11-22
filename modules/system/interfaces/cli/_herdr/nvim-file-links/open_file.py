import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


def local_file(url):
    if not url or re.search(r"[\x00-\x20\x7f]|%(?![\da-fA-F]{2})|[?#]", url):
        raise ValueError("invalid file URL")
    parts = urlsplit(url)
    if parts.scheme != "file" or parts.netloc not in ("", "localhost"):
        raise ValueError("not a local file URL")
    path = unquote(parts.path, errors="strict")
    if not path.startswith("/") or re.search(r"[\x00-\x1f\x7f]", path):
        raise ValueError("invalid absolute path")
    if not Path(path).is_file():
        raise ValueError("not an existing regular file")
    return path


def main():
    try:
        path = local_file(os.environ.get("HERDR_PLUGIN_CLICKED_URL", ""))
        subprocess.run(
            [
                os.environ["HERDR_BIN_PATH"], "plugin", "pane", "open",
                "--plugin", os.environ["HERDR_PLUGIN_ID"],
                "--entrypoint", "editor",
                "--env", f"HERDR_NVIM_FILE={path}",
            ],
            check=True,
        )
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
        print(f"Neovim file link: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
