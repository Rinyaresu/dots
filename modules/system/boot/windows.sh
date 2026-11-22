entries=$(sudo @efibootmgr@)
mapfile -t matches < <(
  printf '%s\n' "$entries" |
    LC_ALL=C awk '/^Boot[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\*[[:space:]]+Windows Boot Manager([[:blank:]]*$|\t)/ {
      print substr($0, 5, 4)
    }'
)
if (( ${#matches[@]} != 1 )); then
  echo "windows: expected exactly one active Windows Boot Manager UEFI entry" >&2
  exit 1
fi

sudo @efibootmgr@ --bootnext "${matches[0]}"
systemctl reboot
