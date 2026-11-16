import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


fish, init_path, function_path, herdr_binary, mise, direnv, mise_config = sys.argv[1:]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory) / "projects with spaces"
    root.mkdir()
    home = root / "home"
    home.mkdir()
    config = home / ".config"
    (config / "mise").mkdir(parents=True)
    (config / "mise/config.toml").write_text(Path(mise_config).read_text())
    env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(config),
           "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
           "XDG_STATE_HOME": str(home / ".local/state"), "MISE_CONFIG_DIR": str(config / "mise"),
           "MISE_DATA_DIR": str(home / ".local/share/mise"), "MISE_CACHE_DIR": str(home / ".cache/mise"),
           "MISE_STATE_DIR": str(home / ".local/state/mise"), "MISE_OFFLINE": "true",
           "HERDR_ENV": "1", "TERM": "xterm-256color",
           "PATH": str(Path(mise).parent) + ":" + str(Path(direnv).parent) + ":" + os.environ["PATH"]}
    env.pop("MISE_PROJECT_MARKER", None)
    env.pop("DIRENV_PROJECT_MARKER", None)
    env.pop("__MISE_DIFF", None)
    env.pop("DIRENV_DIFF", None)
    versions = {"a": "22.0.0", "b": "24.0.0"}
    installs = home / ".local/share/mise/installs"
    for name, version in versions.items():
        runtime = installs / "node" / version / "bin/node"
        runtime.parent.mkdir(parents=True)
        runtime.write_text(f"#!{sys.executable}\nprint('RUNTIME|{name}')\n")
        runtime.chmod(0o755)
        project = root / name
        project.mkdir()
        (project / ".mise.toml").write_text(
            f'[tools]\nnode = "{version}"\n[env]\nMISE_PROJECT_MARKER = "{name}"\n')
        (project / ".envrc").write_text(f'export DIRENV_PROJECT_MARKER="{name}"\n')
    stub = Path(directory) / "herdr"
    stub.write_text(f"#!{sys.executable}\n" + '''import json
import os
from pathlib import Path
Path(os.environ["HERDR_TEST_LOG"]).write_text(json.dumps(dict(os.environ)))
''')
    stub.chmod(0o755)
    env["HERDR_TEST_LOG"] = str(root / "herdr-env.json")
    startup = root / "startup.fish"
    startup.write_text(Path(function_path).read_text().replace(herdr_binary, str(stub))
                       + "\n" + Path(init_path).read_text())
    markers = 'printf "MARKERS|%s|%s\\n" "$MISE_PROJECT_MARKER" "$DIRENV_PROJECT_MARKER"'

    def shell(commands, project="a"):
        result = subprocess.run([fish, "--no-config", "-i", "-c",
                                 f"source '{startup}'; emit fish_prompt; " + commands],
                                env=env, cwd=root / project, capture_output=True,
                                text=True, timeout=15)
        assert result.returncode == 0, result.stdout + result.stderr
        if os.environ.get("SESSION_TEST_DEBUG"):
            print(result.stdout + result.stderr)
        return [line for line in result.stdout.splitlines()
                if line.startswith(("MARKERS|", "RUNTIME|"))]

    assert shell(markers) == ["MARKERS||"]
    for name in ["a", "b"]:
        for command in [[mise, "trust", str(root / name / ".mise.toml")],
                        [direnv, "allow", str(root / name)]]:
            result = subprocess.run(command, env=env, cwd=home,
                                    capture_output=True, text=True, timeout=15)
            assert result.returncode == 0, result.stdout + result.stderr
    transitions = shell(markers + f"; cd '{root / 'b'}'; emit fish_prompt; " + markers
                        + f"; cd '{home}'; emit fish_prompt; " + markers)
    assert transitions == ["MARKERS|a|a", "MARKERS|b|b", "MARKERS||"], transitions
    assert shell("command node; " + f"cd '{root / 'b'}'; emit fish_prompt; command node") == [
        "RUNTIME|a", "RUNTIME|b"]
    assert shell(markers + "; herdr; " + markers) == ["MARKERS|a|a", "MARKERS|a|a"]
    inherited = json.loads((root / "herdr-env.json").read_text())
    assert "MISE_PROJECT_MARKER" not in inherited
    assert "DIRENV_PROJECT_MARKER" not in inherited
    assert inherited["PWD"] == str(root / "a")
    assert str(installs) not in inherited["PATH"]
    (root / "a/.envrc").write_text('export DIRENV_PROJECT_MARKER="changed"\n')
    assert shell(markers) == ["MARKERS|a|"]
    (root / "a/.mise.toml").write_text('[tools]\nnode = "9999.0.0"\n')
    subprocess.run([mise, "trust", str(root / "a/.mise.toml")], env=env,
                   cwd=home, check=True, capture_output=True, timeout=15)
    shell("fish_command_not_found node; " + markers)
    missing_exec = subprocess.run([mise, "exec", "--", "session-fixture-missing-command"], env=env, cwd=root / "a",
                                  capture_output=True, text=True, timeout=15)
    assert missing_exec.returncode != 0, missing_exec.stdout + missing_exec.stderr
    assert sorted(path.name for path in (installs / "node").iterdir()) == ["22.0.0", "24.0.0"]

print("PASS explicit trust/allow, changed envrc refusal, project runtime selection, no missing-runtime install, neutral Herdr PATH/environment, unchanged parent")
