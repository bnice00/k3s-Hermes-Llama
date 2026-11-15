#!/bin/sh
set -e
SRC=/etc/hermes-forgejo      # where the Secret is mounted
H=/home/hermes-agent

if [ -f "$SRC/id_ed25519" ]; then
  install -o hermes-agent -g hermes-agent -m 600 "$SRC/id_ed25519"  "$H/.ssh/id_ed25519"
  install -o hermes-agent -g hermes-agent -m 644 "$SRC/known_hosts" "$H/.ssh/known_hosts"
  install -o hermes-agent -g hermes-agent -m 600 "$SRC/token"       "$H/.forgejo-token"
  if su hermes-agent -c "tea login add --name lair \
      --url http://forgejo-http.forgejo.svc.cluster.local:3000 \
      --token \$(cat $H/.forgejo-token)"; then
    su hermes-agent -c "tea login default lair"
  else
    echo "WARN: tea login failed, check the token in the hermes-forgejo Secret" >&2
  fi
else
  echo "WARN: $SRC not mounted, Forgejo access disabled" >&2
fi

ssh-keygen -A
exec /usr/sbin/sshd -D -e
