#!@python@
"""Provision a Pi-hole v6 hash without putting a password in argv or on disk."""
import getpass
import os
from pathlib import Path
import re
import resource
import subprocess
import sys
import tempfile
import warnings


def main():
    if os.geteuid() != 0 or not sys.stdin.isatty():
        sys.exit("Run as root from an interactive terminal.")
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    os.umask(0o077)
    with warnings.catch_warnings():
        warnings.simplefilter("error", getpass.GetPassWarning)
        password = getpass.getpass("New Pi-hole admin password: ")
        confirmation = getpass.getpass("Confirm password: ")
    if not password or password != confirmation:
        sys.exit("Empty password or confirmation mismatch; nothing changed.")
    result = subprocess.run(
        ["@ftl@", "--config", "-q", "webserver.api.pwhash"],
        env={
            "FTLCONF_webserver_api_pwhash": "",
            "FTLCONF_webserver_api_password": password,
            "FTLCONF_debug_config": "false",
        },
        capture_output=True,
        text=True,
        check=True,
    )
    password = confirmation = None
    value = result.stdout.strip()
    if not re.fullmatch(r"\$BALLOON-SHA256\$v=1\$s=1024,t=32\$[A-Za-z0-9+/]{21}[AQgw]==\$[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=", value):
        sys.exit("FTL did not return a valid hash; nothing changed. Check /etc/pihole/pihole.toml.")
    directory = Path("/var/lib/pihole-secrets")
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.is_symlink() or directory.stat().st_uid != 0:
        sys.exit("Unsafe credential directory; nothing changed.")
    directory.chmod(0o700)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=directory, delete=False) as output:
            name = output.name
            output.write(value + "\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(name, directory / "admin-hash")
    finally:
        if name and os.path.exists(name):
            os.unlink(name)
    print("Hash installed. Restart pihole-ftl.service to apply; password was not stored.")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError, getpass.GetPassWarning):
        sys.exit("Cancelled; nothing changed.")
