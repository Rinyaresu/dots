import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


script, bin_dir, scratch = map(Path, sys.argv[1:])
now = time.time()
day = 24 * 60 * 60

with tempfile.TemporaryDirectory(dir=scratch) as tmp:
    root = Path(tmp)
    state = root / "state"
    store = f"local?store={root / 'store'}&state={state}&log={root / 'log'}"
    profile = state / "profiles" / "system"
    boot = root / "boot"
    entries = boot / "loader" / "entries"
    images = boot / "EFI" / "nixos"
    runtime = root / "run"
    for directory in (profile.parent, entries, images, runtime):
        directory.mkdir(parents=True)

    def add_fixture(name, executable=True):
        source = root / name
        source.mkdir()
        init = source / "init"
        init.write_text(name)
        if executable:
            init.chmod(0o755)
        return Path(
            subprocess.check_output(
                [bin_dir / "nix-store", "--store", store, "--add", source],
                text=True,
            ).strip()
        )

    def generation(number, age, target):
        link = profile.with_name(f"system-{number}-link")
        link.symlink_to(target)
        os.utime(link, times=(now - age, now - age), follow_symlinks=False)
        return link

    def entry(number, target, microcode="microcode"):
        (entries / f"nixos-generation-{number}.conf").write_text(
            "linux /EFI/nixos/kernel\n"
            f"initrd /EFI/nixos/{microcode}\n"
            "initrd /EFI/nixos/initrd\n"
            f"options init={target}/init quiet\n"
        )

    def collect():
        return subprocess.run(
            [sys.executable, script, bin_dir, store, profile, boot, runtime],
            capture_output=True,
            text=True,
        )

    for image in ("kernel", "microcode", "initrd"):
        (images / image).write_text(image)

    expired = add_fixture("expired")
    old = generation(1, 30 * day + 3600, expired)
    booted = add_fixture("booted")
    previous_boot = generation(2, 90 * day, booted)
    rollback = add_fixture("rollback")
    fallback = generation(3, 75 * day, rollback)
    current = add_fixture("current")
    active = generation(4, 60 * day, current)
    fresh = add_fixture("fresh")
    recent = generation(5, 30 * day - 3600, fresh)
    duplicate = generation(6, 50 * day, current)
    nonexec = add_fixture("nonexec", executable=False)
    unusable = generation(7, 31 * day, nonexec)
    unrooted = add_fixture("unrooted")
    unrelated = add_fixture("unrelated")
    other_profile = profile.with_name("other-1-link")
    other_profile.symlink_to(unrelated)
    os.utime(other_profile, times=(now - 80 * day,) * 2, follow_symlinks=False)

    profile.symlink_to(active.name)
    (runtime / "current-system").symlink_to(current)
    (runtime / "booted-system").symlink_to(booted)
    entry(3, rollback, microcode="missing")
    entry(4, current)
    entry(5, unrelated)
    entry(6, current)
    entry(7, nonexec)

    result = collect()
    assert result.returncode != 0, result
    assert "no second distinct bootable system generation" in result.stderr, result
    assert all(
        link.is_symlink()
        for link in (old, previous_boot, fallback, active, recent, duplicate, unusable, other_profile)
    ), result
    assert all(path.is_dir() for path in (expired, rollback, unrooted)), result
    print("GC rejects missing first initrd, nonexecutable init, and duplicate targets as fallbacks")

    entry(3, rollback)
    result = collect()
    assert result.returncode == 0, result
    assert profile.readlink() == Path(active.name)
    assert all(
        link.is_symlink()
        for link in (previous_boot, fallback, active, recent, duplicate, other_profile)
    ), result
    assert all(path.is_dir() for path in (booted, rollback, current, fresh, unrelated)), result
    assert not old.is_symlink() and not expired.exists(), result
    assert not unusable.is_symlink() and not nonexec.exists(), result
    assert not unrooted.exists(), result
    print("GC retains the old recovery pair, the booted system, recent generations, and other profiles")
    print("GC reclaims the expired generation and the unrelated unrooted fixture")

    entry(4, unrelated)
    unrooted = add_fixture("invalid-active")
    result = collect()
    assert result.returncode != 0, result
    assert "no matching boot entry" in result.stderr and unrooted.is_dir(), result
    print("GC fails closed when the current profile does not match its boot entry")
