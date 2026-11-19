"""Install an isolated setup override in the disposable test guest only."""
from pathlib import Path
import re
import subprocess
import sys

mode, observer = sys.argv[1:]
unit = subprocess.check_output(['systemctl', 'cat', 'pihole-ftl-setup.service'], text=True)
entry, = re.findall(r'^ExecStart=(/nix/store/\S+)\s*$', unit, re.M)
script = Path(entry).read_text()
api, = re.findall(r'^source (/nix/store/\S+/api\.sh)$', script, re.M)
base = Path('/etc/pihole-test')
base.mkdir(exist_ok=True)
local_api = base / 'api.sh'
local_api.write_text(Path(api).read_text())
if mode == 'observe':
    subprocess.run([sys.executable, observer, str(local_api)], check=True)
elif mode == 'invalid':
    src = local_api.read_text()
    assert src.count('GetFTLData() {') == 1
    local_api.write_text(src.replace('GetFTLData() {', 'GetFTLData() {\n  if [[ "$1" == lists\\?* ]]; then printf \'%s\' \'{"lists":{}}\'; return; fi'))
else:
    raise ValueError(mode)
entry = base / 'pihole-ftl-setup-start'
entry.write_text(script.replace(api, str(local_api)))
entry.chmod(0o755)
drop = Path('/etc/systemd/system/pihole-ftl-setup.service.d')
drop.mkdir(exist_ok=True)
(drop / '99-vm-test.conf').write_text(f'[Service]\nExecStart=\nExecStart={entry}\n')
subprocess.run(['systemctl', 'daemon-reload'], check=True)
