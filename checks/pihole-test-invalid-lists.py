"""Inject a malformed list response in the disposable guest's setup only."""
from pathlib import Path
import re
import subprocess

unit = subprocess.check_output(['systemctl', 'cat', 'pihole-ftl-setup.service'], text=True)
entry, = re.findall(r'^ExecStart=(/nix/store/\S+)\s*$', unit, re.M)
script = Path(entry).read_text()
api, = re.findall(r'^source (/nix/store/\S+/api\.sh)$', script, re.M)
base = Path('/run/pihole-test')
base.mkdir(mode=0o755)
local_api = base / 'api.sh'
source = Path(api).read_text()
function = 'GetFTLData() {'
assert source.count(function) == 1
local_api.write_text(source.replace(function, function + r'''
  if [[ "$1" == lists\?* ]]; then printf '%s' '{"lists":{}}'; return; fi'''))
entry = base / 'setup'
entry.write_text(script.replace(api, str(local_api)))
entry.chmod(0o755)
drop_in = Path('/run/systemd/system/pihole-ftl-setup.service.d')
drop_in.mkdir(parents=True, exist_ok=True)
(drop_in / '90-test-invalid-lists.conf').write_text(f'[Service]\nExecStart=\nExecStart={entry}\n')
subprocess.run(['systemctl', 'daemon-reload'], check=True)
