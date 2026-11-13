#!/bin/sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cat > "$DIR/all.yaml"
kubectl kustomize "$DIR"
rm -f "$DIR/all.yaml"
