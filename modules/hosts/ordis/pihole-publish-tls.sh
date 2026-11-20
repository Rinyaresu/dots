name=$1
source=$2
dest=$3
ca=$4
umask 077

# NixOS also provisions a preliminary self-signed certificate. Never serve it.
test -f "$source/acme-success"
fullchain=$source/fullchain.pem
key=$source/key.pem
pem=$dest/server.pem
candidate=$(mktemp "$dest/.candidate.XXXXXXXX")
previous=
trap 'rm -f -- "$candidate" ${previous:+"$previous"}' EXIT

if ! { cat "$fullchain"; openssl pkey -in "$key" -passin pass:; } >"$candidate"; then
  echo 'Pi-hole TLS: cannot assemble candidate; keeping previous PEM' >&2
  exit 1
fi
if ! openssl verify -CAfile "$ca" -untrusted "$candidate" -purpose sslserver \
     -verify_hostname "$name" "$candidate" ||
   ! openssl x509 -in "$candidate" -checkend 86400 -noout ||
   [[ $(openssl x509 -in "$candidate" -pubkey -noout) != $(openssl pkey -in "$candidate" -passin pass: -pubout) ]]; then
  echo 'Pi-hole TLS: invalid candidate; keeping previous PEM' >&2
  exit 1
fi
if cmp -s "$candidate" "$pem"; then
  exit 0
fi
chgrp pihole "$candidate"
chmod 0640 "$candidate"
sync -d "$candidate"
if [[ -f "$pem" ]]; then
  previous=$(mktemp "$dest/.previous.XXXXXXXX")
  cp -p -- "$pem" "$previous"
fi
mv -fT -- "$candidate" "$pem"
sync -f "$dest"
if ! systemctl try-restart pihole-ftl.service; then
  echo 'Pi-hole TLS: restart failed; restoring previous listener credentials' >&2
  if [[ -n "$previous" ]]; then mv -fT -- "$previous" "$pem"; else rm -f -- "$pem"; fi
  sync -f "$dest"
  systemctl start pihole-ftl.service || true
  exit 1
fi
echo 'Pi-hole TLS: certificate published'
