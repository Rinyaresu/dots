# Sourced into a writeShellApplication, which sets errexit, nounset and pipefail.
die() {
  printf 'desktop-disk-guard: %s\n' "$*" >&2
  exit 1
}

if [[ "${1:-}" == refuse-destroy ]]; then
  die "generic Disko destroy is disabled; use the guarded desktop formatMount script"
fi

# Private input is mandatory at runtime. Never source it as shell code.
file=$runtime_dir/inventory.json
[[ ! -L "$runtime_dir" && -d "$runtime_dir" && $(stat -c '%u:%a' -- "$runtime_dir") == 0:700 ]] ||
  die "expected a root-owned runtime directory (0700)"
[[ ! -L "$file" && -f "$file" && $(stat -c '%u:%a' -- "$file") == 0:600 ]] ||
  die "expected a root-owned private inventory (0600)"
inv=$(jq -ces '
  def guid: type == "string" and test("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$");
  select(length == 1) | .[0] |
  select(type == "object" and keys == ["byId", "bytes", "model", "originalEsp", "originalRoot", "windowsEsp"]) |
  select((.byId | type == "string" and test("^(ata|virtio)-[A-Za-z0-9_.+-]+$")) and
    (.bytes | type == "number" and . > 0 and . < 1e15 and floor == .) and
    (.model | type == "string" and (test("[[:cntrl:]]") | not)) and
    ([.originalEsp, .originalRoot, .windowsEsp] | all(.[]; guid) and (unique | length == 3)))
' "$file" 2>/dev/null) || die "invalid private inventory"
by_id=$(jq -r .byId <<< "$inv")
by_id=/dev/disk/by-id/$by_id
expected_id=${by_id##*/}
expected_id=${expected_id#ata-}
expected_id=${expected_id#virtio-}
expected_model=$(jq -r .model <<< "$inv")
expected_bytes=$(jq -r .bytes <<< "$inv")
old_esp=$(jq -r .originalEsp <<< "$inv")
old_root=$(jq -r .originalRoot <<< "$inv")
windows_esp=$(jq -r .windowsEsp <<< "$inv")

probe() {
  # No fallback to an enumerated name; verify the actual block object too.
  [[ -L "$by_id" && -b "$by_id" ]] || die "expected whole-disk by-id missing"
  disk=$(realpath -e -- "$by_id")
  [[ $(lsblk -dnro TYPE -- "$disk") == disk ]] || die "target is not a whole disk"
  udev=$(udevadm info --query=property --name="$disk")
  grep -Fxq "ID_SERIAL=$expected_id" <<< "$udev" || die "device serial does not match inventory"
  [[ $(lsblk -dnro MODEL -- "$disk") == "$expected_model" ]] || die "device model does not match inventory"
  [[ $(blockdev --getsize64 "$disk") == "$expected_bytes" ]] || die "device capacity does not match inventory"

  all_guids=$(lsblk -nro PARTUUID)
  tree=$(lsblk -Jbo NAME,TYPE,PARTUUID,MOUNTPOINTS -- "$disk")
  jq -e --arg guid "$windows_esp" 'all(.. | objects; .partuuid != $guid)' <<< "$tree" >/dev/null ||
    die "protected Windows EFI is on the proposed target"
  [[ $(grep -Fxc -- "$windows_esp" <<< "$all_guids") == 1 ]] || die "protected Windows EFI is missing or duplicated"
}

partition() {
  local guid=$1 part
  local -a matches
  mapfile -t matches < <(awk -v guid="$guid" '$1 == guid' <<< "$all_guids")
  [[ ${#matches[@]} == 1 ]] || die "missing or duplicate partition GUID"
  part=$(realpath -eq -- "/dev/disk/by-partuuid/$guid") || die "partition link missing"
  [[ -b "$part" ]] || die "partition link is not a block device"
  [[ $(lsblk -dnro PKNAME -- "$part") == "${disk##*/}" &&
     $(lsblk -dnro TYPE -- "$part") == part &&
     $(lsblk -dnro PARTUUID -- "$part") == "$guid" ]] || die "partition does not belong to verified disk"
  printf '%s\n' "$part"
}

check_original() {
  old_esp_device=$(partition "$old_esp")
  old_root_device=$(partition "$old_root")
  [[ ! -e "$target" && ! -L "$target" ]] || die "runtime disk alias already exists"
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
  [[ ! -L "$mount_root" ]] || die "$mount_root is a symlink"
  mounts=$(findmnt --raw --noheadings --output TARGET)
  if grep -Eq "^$mount_root(/|$)" <<< "$mounts"; then
    die "$mount_root has active mounts"
  fi
}

probe
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
    original_disk=$disk
    probe
    [[ "$disk" == "$original_disk" ]] || die "device changed"
    check_original
    # No overwrite. Bind Disko's fixed public path to the verified device.
    ln -sT -- "$disk" "$target"
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
