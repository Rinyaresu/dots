start_all()
machine.wait_for_unit("multi-user.target")
machine.succeed("systemctl is-enabled nix-gc.timer btrfs-scrub-home.timer smartd.service")
machine.succeed("systemctl is-active nix-gc.timer btrfs-scrub-home.timer")
machine.succeed("grep -Eq '^/dev/zram[0-9]+[[:space:]]' /proc/swaps")
machine.succeed("grep -F '[zstd]' /sys/block/zram0/comp_algorithm")
machine.succeed("systemctl start btrfs-scrub-home.service")
machine.wait_until_succeeds("btrfs scrub status /home | grep -E 'Status:[[:space:]]+finished'")

def snapshots():
    output = machine.succeed(
        "find /home/.snapshots -mindepth 1 -maxdepth 1 -type d -printf '%f\\n'"
    )
    return sorted(int(number) for number in output.splitlines() if number.isdigit())

machine.succeed(
    "set -eu; install -d -m 0700 -o alice -g users /home/alice; "
    "su - alice -c 'umask 077; echo before > note'; "
    "mkdir -p /var/lib/systemd/timers; "
    "touch -d '2000-01-01 00:00:00 UTC' "
    "/var/lib/systemd/timers/stamp-snapper-timeline.timer; "
    "systemctl start snapper-timeline.timer"
)
machine.wait_until_succeeds("test -f /home/.snapshots/1/snapshot/alice/note")
machine.succeed("set -eu; systemctl stop snapper-timeline.timer; systemctl start snapper-cleanup.service")
assert snapshots() == [1], snapshots()
machine.succeed("grep -Fx before /home/.snapshots/1/snapshot/alice/note")
machine.succeed("test \"$(stat -c '%U:%G:%a' /home/.snapshots)\" = root:root:700")
machine.fail("su - alice -c 'cat /home/.snapshots/1/snapshot/alice/note'")
machine.fail("su - alice -c 'snapper -c home list'")
machine.fail("systemctl cat snapper-boot.service")
machine.fail("test -e /.snapshots")
machine.succeed("snapper -c home delete 1")

for day in range(1, 10):
    machine.succeed(
        f"set -eu; date -u -s '2030-01-{day:02d} 12:00:00'; "
        f"su - alice -c 'echo day-{day} > note'; "
        "systemctl reset-failed snapper-timeline.service; "
        "systemctl start snapper-timeline.service"
    )
    assert len(snapshots()) == min(day, 7), (day, snapshots())

retained = snapshots()
assert len(retained) == 7, retained
for number, day in zip(retained, range(3, 10)):
    machine.succeed(
        f"set -eu; grep -Fx day-{day} /home/.snapshots/{number}/snapshot/alice/note; "
        f"btrfs property get /home/.snapshots/{number}/snapshot ro | grep -Fx ro=true"
    )
oldest = retained[0]
machine.succeed(
    f"set -eu; cp -a /home/.snapshots/{oldest}/snapshot/alice/note /home/alice/restored; "
    "test \"$(stat -c '%U:%G:%a' /home/alice/restored)\" = alice:users:600; "
    "su - alice -c 'grep -Fx day-3 restored'; "
    "su - alice -c 'grep -Fx day-9 note'"
)
machine.succeed("systemctl start snapper-cleanup.service")
assert snapshots() == retained, (snapshots(), retained)
machine.succeed("systemctl restart home-snapshots-prepare.service")
assert snapshots() == retained, (snapshots(), retained)
machine.succeed("test \"$(stat -c '%U:%G:%a' /home/.snapshots)\" = root:root:700")
machine.fail("test -e /.snapshots")
