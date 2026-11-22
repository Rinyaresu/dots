import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Generation:
    number: int
    target: Path
    created: float

    def has_boot_entry(self, boot):
        entry = boot / "loader" / "entries" / f"nixos-generation-{self.number}.conf"
        try:
            lines = entry.read_text().splitlines()
        except FileNotFoundError:
            return False

        fields = {}
        for line in lines:
            if (parts := line.strip().split(maxsplit=1)) and not parts[0].startswith("#"):
                key, *value = parts
                fields.setdefault(key.lower(), []).append("".join(value))

        init = self.target / "init"
        options = " ".join(fields.get("options", [])).split()
        init_args = [arg for arg in options if arg.startswith("init=")]
        if not init.is_file() or not os.access(init, os.X_OK) or init_args != [f"init={init}"]:
            return False

        kernels = fields.get("linux", [])
        initrds = fields.get("initrd", [])
        if len(kernels) != 1 or not initrds:
            return False
        for value in kernels + initrds:
            path = Path(value)
            if not path.is_absolute() or ".." in path.parts:
                return False
            image = boot / path.relative_to("/")
            if not image.is_file() or image.stat().st_size == 0:
                return False
        return True


def collect(nix_bin, store, profile, boot, runtime):
    cutoff = time.time() - 30 * 24 * 60 * 60
    candidates = {}
    pattern = re.compile(rf"{re.escape(profile.name)}-([1-9][0-9]*)-link")
    for link in profile.parent.iterdir():
        match = pattern.fullmatch(link.name)
        if match and link.is_symlink():
            candidates[link.name] = Generation(
                int(match[1]), link.readlink(), link.lstat().st_mtime
            )

    selected = profile.readlink()
    active = candidates.get(str(selected))
    if active is None or not active.has_boot_entry(boot):
        raise ValueError("the system profile has no matching boot entry")

    ordered = sorted(candidates.values(), key=lambda gen: gen.number, reverse=True)
    fallback = next(
        (
            gen
            for gen in ordered
            if gen.target != active.target and gen.has_boot_entry(boot)
        ),
        None,
    )
    if fallback is None:
        raise ValueError("no second distinct bootable system generation")

    system_targets = {
        (runtime / name).resolve(strict=True)
        for name in ("current-system", "booted-system")
    }
    subprocess.run(
        [
            nix_bin / "nix-store",
            "--store",
            store,
            "--query",
            "--requisites",
            active.target,
            fallback.target,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    expired = [
        str(gen.number)
        for gen in ordered
        if gen.number not in (active.number, fallback.number)
        and gen.target not in system_targets
        and gen.created < cutoff
    ]
    if selected != profile.readlink():
        raise ValueError("the system profile changed during retention checks")

    if expired:
        subprocess.run(
            [
                nix_bin / "nix-env",
                "--store",
                store,
                "--profile",
                profile,
                "--delete-generations",
                *expired,
            ],
            check=True,
        )
    subprocess.run([nix_bin / "nix-store", "--store", store, "--gc"], check=True)


if __name__ == "__main__":
    nix_bin, store, profile, boot, runtime = sys.argv[1:]
    try:
        collect(Path(nix_bin), store, Path(profile), Path(boot), Path(runtime))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Ordis Nix GC stopped: {error}")
