#!/bin/sh
set -e
SRC=/etc/hermes-forgejo      # where the Secret will be mounted
H=/home/hermes-agent

if [ -f "$SRC/id_ed25519" ]; then
  install -o hermes-agent -g hermes-agent -m 600 "$SRC/id_ed25519"  "$H/.ssh/id_ed25519"
  install -o hermes-agent -g hermes-agent -m 644 "$SRC/known_hosts" "$H/.ssh/known_hosts"
  install -o hermes-agent -g hermes-agent -m 600 "$SRC/token"       "$H/.forgejo-token"
  su hermes-agent -c "tea login add --name lair \
      --url http://forgejo-http.forgejo.svc.cluster.local:3000 \
      --token \$(cat $H/.forgejo-token)" 2>/dev/null || true
fi

ssh-keygen -A
exec /usr/sbin/sshd -D -e
