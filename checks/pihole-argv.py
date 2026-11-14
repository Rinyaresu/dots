"""Check the shipped API client while real gravity setup runs in the VM."""
from pathlib import Path
import subprocess
import sys
import time

# Also guard call sites too short-lived for /proc sampling.
source = Path(sys.argv[1]).read_text()
assert '-H "sid: ${SID}"' not in source
assert '--data "{\\"password' not in source
assert "--data @<(printf" in source
process = subprocess.Popen(["systemctl", "start", "pihole-ftl-setup.service"])
seen_curl = False
while process.poll() is None:
    for path in Path("/proc").glob("[0-9]*/cmdline"):
        try:
            argv = path.read_bytes().split(b"\0")
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        if argv and b"curl" in argv[0]:
            seen_curl = True
            assert not any(b'"password":' in arg or arg.startswith(b"sid: ") for arg in argv), "API credential in curl argv"
    time.sleep(0.001)
assert process.wait() == 0
assert seen_curl, "No real curl invocation observed"
print(f"No API credentials observed in curl argv; curl observed: {seen_curl}")
