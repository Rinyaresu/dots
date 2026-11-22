import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import tomllib

plugin, plannotator, herdr, links = map(Path, sys.argv[1:])
config = tomllib.loads(herdr.read_text())
assert config["theme"]["name"] == "rose-pine-dawn"
assert config["keys"]["prefix"] == "ctrl+b" and config["keys"]["detach"] == "prefix+d"
commands = {entry["key"]: entry["command"] for entry in config["keys"]["command"]}
assert commands == {
    "prefix+f": "sessionizer", "prefix+u": "herdr-links", "prefix+a": "annotate.capture",
    "prefix+shift+a": "annotate.copy-context", "prefix+ctrl+a": "annotate.copy-archive",
    "prefix+ctrl+v": "annotate.paste-archive", "prefix+ctrl+s": "annotate.send-archive",
    "prefix+m": "annotate.manage", "prefix+alt+o": "annotate.open", "prefix+shift+o": "annotate.last",
    "prefix+ctrl+o": "annotate.last-newest", "prefix+t": "annotate.terminal",
}
palette = tomllib.loads(plannotator.read_text())
assert palette == {"ui": {"theme": "light"}, "colors": {
    "accent": "#907aa9", "heading": "#286983", "comment": "#907aa9", "looks-good": "#286983",
    "delete": "#b4637a", "comment-bg": "#f2e9e1", "looks-good-bg": "#fffaf3", "block": "#fffaf3",
    "toolbar": "#f2e9e1", "cursor": "#cecacd", "selection": "#dfdad9",
}}
local_file = runpy.run_path(str(plugin / "open_file.py"))["local_file"]
urls = runpy.run_path(str(links))["extract_urls"]
assert urls("\x1b]8;;https://hidden.example\x07\x1b[1mhttps://shown.example/a(b)\x1b[0m; "
            "(https://other.example). https://shown.example/a(b)") == [
                "https://shown.example/a(b)", "https://other.example"]
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "file with spaces #?.md"
    path.touch()
    url = path.as_uri()
    assert local_file(url) == str(path)
    for invalid in (url.replace("file://", "file://remote.example", 1), url + "#1", url + "?x",
                    path.parent.as_uri(), url + "missing", url + "%00"):
        try:
            local_file(invalid)
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid URL accepted: {invalid}")
    stub = Path(directory) / "herdr"
    stub.write_text(f"#!{sys.executable}\nimport sys\nprint(*sys.argv[1:], sep='\\n')\n")
    stub.chmod(0o755)
    result = subprocess.run([sys.executable, plugin / "open_file.py"], capture_output=True, text=True,
                            env={**os.environ, "HERDR_BIN_PATH": str(stub), "HERDR_PLUGIN_CLICKED_URL": url,
                                 "HERDR_PLUGIN_ID": "local.nvim-file-links"}, check=True)
    assert result.stdout.splitlines() == ["plugin", "pane", "open", "--plugin", "local.nvim-file-links",
                                          "--entrypoint", "editor", "--env", f"HERDR_NVIM_FILE={path}"]
print("PASS isolated plugin registration, Neovim link argv, visible HTTP links, Herdr bindings and Plannotator palette")
