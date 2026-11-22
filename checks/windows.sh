set -eu
script=$1
export LOG="$PWD/windows.log"

sudo() {
  [[ $1 == /test/efibootmgr ]] || exit 99
  shift
  if (( $# == 0 )); then
    printf '%s\n' "$ENTRIES"
  else
    printf '%s\n' "$*" >> "$LOG"
    return "${SET_STATUS:-0}"
  fi
}
systemctl() { printf '%s\n' "$*" >> "$LOG"; }
export -f sudo systemctl

ENTRIES=$'Boot0000* Linux\nBoot00aF* Windows Boot Manager\tHD(2,GPT,fixture)\nBoot00b0* Windows Boot Manager Recovery\nBoot0001 Windows Boot Manager'
export ENTRIES
( source "$script" )
[[ $(<"$LOG") == $'--bootnext 00aF\nreboot' ]]

: > "$LOG"
if ( export SET_STATUS=1; bash -e "$script" ); then exit 1; fi
[[ $(<"$LOG") == '--bootnext 00aF' ]]

: > "$LOG"
for ENTRIES in 'Boot0000* Linux' $'Boot0000* Windows Boot Manager\nBoot0001* Windows Boot Manager'; do
  if ( bash -e "$script" ); then exit 1; fi
  [[ ! -s $LOG ]]
done
