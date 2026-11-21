linux = "/dev/disk/by-id/virtio-dots-linux"
windows = "/dev/disk/by-id/virtio-dots-windows"
old_esp = inventory["originalEsp"]
old_root = inventory["originalRoot"]
windows_esp = inventory["windowsEsp"]


def reject(script, message):
    status, output = installer.execute(f"printf 'ERASE-LINUX\\n' | {script}")
    assert status != 0 and message in output, output


installer.start()
installer.wait_until_succeeds(f"test -b {linux} && test -b {windows}")

with subtest("seed two disposable block devices"):
    installer.succeed(
        f"sgdisk -n 1:0:+64M -t 1:ef00 -u 1:{old_esp} "
        f"-n 2:0:0 -u 2:{old_root} {linux}",
        f"sgdisk -n 1:0:+64M -t 1:ef00 -u 1:{windows_esp} -n 2:0:0 {windows}",
        f"partprobe {linux} {windows}",
        "udevadm settle",
        f"mkfs.fat -F 32 /dev/disk/by-partuuid/{old_esp}",
        f"mkfs.btrfs -f /dev/disk/by-partuuid/{old_root}",
        f"mkfs.fat -F 32 /dev/disk/by-partuuid/{windows_esp}",
        "echo fixture-windows-loader >/tmp/bootmgfw.efi",
        f"mmd -i /dev/disk/by-partuuid/{windows_esp} ::/EFI ::/EFI/Microsoft ::/EFI/Microsoft/Boot",
        f"mcopy -i /dev/disk/by-partuuid/{windows_esp} /tmp/bootmgfw.efi ::/EFI/Microsoft/Boot/",
        f"printf 'Windows data sentinel' | dd of={windows}-part2 conv=notrunc status=none",
        f"sync; sha256sum {windows} > /tmp/windows.before",
        f"sha256sum {linux} > /tmp/linux.before",
    )

with subtest("reject missing or wrong target and protect Windows even if selected explicitly"):
    installer.succeed(f"{guard} preflight", f"mv {linux} {linux}.saved")
    reject(format_linux, "by-id missing")
    installer.succeed(f"ln -s $(realpath {windows}) {linux}")
    reject(format_linux, "serial does not match")
    installer.succeed(f"rm {linux}; mv {linux}.saved {linux}")
    reject(format_wrong, "capacity does not match")
    reject(format_windows, "protected Windows EFI")
    reject(destroy, "generic Disko destroy is disabled")
    reject(legacy_destroy, "generic Disko destroy is disabled")
    installer.succeed("mkdir -p /mnt; mount -t tmpfs tmpfs /mnt")
    reject(format_linux, "/mnt has active mounts")
    installer.succeed(
        "umount /mnt",
        "sha256sum -c /tmp/linux.before /tmp/windows.before",
        f"test -z \"$(lsblk -nro MOUNTPOINTS {windows} | tr -d '[:space:]')\"",
    )

with subtest("format and mount only Linux using the evaluated layout"):
    installer.succeed(f"printf 'ERASE-LINUX\\n' | {format_linux}")
    installer.succeed(
        f"{guard} installed",
        f"test $(lsblk -ndo PTTYPE {linux}) = gpt",
        f"test $(lsblk -ndo LABEL {filesystems['/boot']['device']}) = NIXOS_BOOT",
        f"test $(lsblk -ndo FSVER {filesystems['/boot']['device']}) = FAT32",
        f"test $(lsblk -ndo PARTTYPE {filesystems['/boot']['device']}) "
        "= c12a7328-f81f-11d2-ba4b-00a0c93ec93b",
        f"test $(lsblk -ndo LABEL {filesystems['/']['device']}) = NIXOS",
        f"sgdisk -v {linux} | grep 'No problems found'",
    )
    for path, fs in filesystems.items():
        dest = "/mnt" + (path if path != "/" else "")
        assert not fs["luks"]
        assert installer.succeed(f"findmnt -n -M {dest} -o FSTYPE").strip() == fs["fsType"]
        assert (
            installer.succeed(f"findmnt -n -M {dest} -o MAJ:MIN").strip()
            == installer.succeed(f"lsblk -dnro MAJ:MIN {fs['device']}").strip()
        )
        opts = installer.succeed(f"findmnt -n -M {dest} -o OPTIONS").strip().split(",")
        for option in fs["options"]:
            if option.startswith("subvol="):
                assert "subvol=/" + option.removeprefix("subvol=") in opts, opts
            elif option == "compress=zstd":
                assert any(o == option or o.startswith(option + ":") for o in opts), opts
            elif option == "umask=0077":
                assert "fmask=0077" in opts and "dmask=0077" in opts, opts
            else:
                assert option == "x-initrd.mount", option

with subtest("no repeated wipe; repeatable mount and intact Windows"):
    installer.succeed("touch /mnt/home/persist; sync")
    reject(format_linux, "missing or duplicate partition GUID")
    installer.succeed(
        f"{mount_linux}",
        "test -f /mnt/home/persist",
        "umount /mnt/boot /mnt/home /mnt/nix /mnt",
        f"{mount_linux}",
        "test -f /mnt/home/persist",
        "sha256sum -c /tmp/windows.before",
        f"mtype -i /dev/disk/by-partuuid/{windows_esp} ::/EFI/Microsoft/Boot/bootmgfw.efi "
        "| grep -Fx fixture-windows-loader",
        f"test -z \"$(lsblk -nro MOUNTPOINTS {windows} | tr -d '[:space:]')\"",
    )
