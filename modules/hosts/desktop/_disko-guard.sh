# Sourced into a writeShellApplication, which sets errexit, nounset and pipefail.
die() {
  printf 'desktop-disk-guard: %s\n' "$*" >&2
  exit 1
}

# No fallback to an enumerated name. Verify the object behind the symlink too.
[[ -L "$target" && -b "$target" ]] || die "expected whole-disk by-id missing"
disk=$(realpath -e -- "$target")
[[ $(lsblk -dnro TYPE -- "$disk") == disk ]] || die "target is not a whole disk"
udev=$(udevadm info --query=property --name="$disk")
grep -Fxq "ID_SERIAL=$expected_id" <<< "$udev" || die "device serial does not match inventory"
[[ $(lsblk -dnro MODEL -- "$disk") == "$expected_model" ]] || die "device model does not match inventory"
[[ $(blockdev --getsize64 "$disk") == "$expected_bytes" ]] || die "device capacity does not match inventory"

partition() {
  local guid=$1 part
  local -a matches
  mapfile -t matches < <(awk -v guid="$guid" '$1 == guid' <<< "$all_guids")
  [[ ${#matches[@]} == 1 ]] || die "missing or duplicate partition GUID: $guid"
  part=$(realpath -e -- "/dev/disk/by-partuuid/$guid") || die "partition link missing: $guid"
  [[ -b "$part" ]] || die "partition link is not a block device"
  [[ $(lsblk -dnro PKNAME -- "$part") == "${disk##*/}" &&
     $(lsblk -dnro TYPE -- "$part") == part &&
     $(lsblk -dnro PARTUUID -- "$part") == "$guid" ]] || die "partition does not belong to verified disk"
  printf '%s\n' "$part"
}

all_guids=$(lsblk -lnro PARTUUID)
tree=$(lsblk -Jbo NAME,TYPE,PARTUUID,MOUNTPOINTS -- "$disk")
jq -e --arg guid "$windows_esp" 'all(.. | objects; .partuuid != $guid)' <<< "$tree" >/dev/null ||
  die "protected Windows EFI is on the proposed target"

check_original() {
  old_esp_device=$(partition "$old_esp")
  old_root_device=$(partition "$old_root")
  [[ $(blkid -p -s TYPE -o value -- "$old_esp_device") == vfat &&
     $(blkid -p -s TYPE -o value -- "$old_root_device") == btrfs ]] ||
    die "original EFI or root filesystem does not match inventory"
  jq -e '
    .blockdevices[0] |
    (.children | length == 2 and all(.[]; .type == "part" and (has("children") | not))) and
    all(.. | objects; all(.mountpoints[]?; . == null))
  ' <<< "$tree" >/dev/null || die "unexpected disk topology, active mount, or swap"
  if grep -Fxqe "$esp" -e "$root" <<< "$all_guids"; then
    die "new Linux GPT identities already exist"
  fi
  mounts=$(findmnt --raw --noheadings --output TARGET)
  if grep -Eq "^$mount_root(/|$)" <<< "$mounts"; then
    die "$mount_root has active mounts"
  fi
}

case "${1:-}" in
  preflight)
    check_original
    printf 'Verified Linux target: %s -> %s (%s bytes)\n' "$target" "$disk" "$expected_bytes"
    ;;
  wipe)
    check_original
    # This is the only destructive entry point. Verify again after the prompt.
    printf 'ERASE CachyOS on %s -> %s (%s bytes). Type ERASE-LINUX to proceed: ' \
      "$target" "$disk" "$expected_bytes" >&2
    read -r confirmation || die "confirmation required"
    [[ "$confirmation" == ERASE-LINUX ]] || die "not confirmed"
    "${BASH_SOURCE[0]}" preflight
    [[ $(realpath -e -- "$target") == "$disk" ]] || die "device changed"
    wipefs --lock=yes --all -- "$old_esp_device" "$old_root_device" "$disk"
    udevadm settle --timeout=120
    ;;
  partition)
    [[ "$2" == "$esp" || "$2" == "$root" ]] || die "unknown destination partition"
    partition "$2" >/dev/null
    ;;
  installed)
    partition "$esp" >/dev/null
    partition "$root" >/dev/null
    ;;
  *) die "expected preflight, wipe, partition, or installed" ;;
esac
