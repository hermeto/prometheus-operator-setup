#!/usr/bin/env bash
# Extracts the Alertmanager configuration from a rendered kube-prometheus-stack
# manifest and validates it with amtool.
#
# Usage: scripts/check-alertmanager-config.sh <rendered-manifest.yaml>
# AMTOOL can point to a local binary; by default amtool runs from the official image.
set -euo pipefail

manifest="${1:?usage: $0 <rendered-manifest.yaml>}"
alertmanager_image="${ALERTMANAGER_IMAGE:-prom/alertmanager:v0.34.1}"

encoded="$(grep -E '^\s+alertmanager\.yaml: ' "$manifest" | head -n1 | sed -E 's/^\s+alertmanager\.yaml: "?([^"]*)"?$/\1/')"
if [[ -z "$encoded" ]]; then
  echo "no alertmanager.yaml found in $manifest" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
chmod 755 "$workdir"
printf '%s' "$encoded" | base64 -d > "$workdir/alertmanager.yaml"
chmod 644 "$workdir/alertmanager.yaml"

if [[ -n "${AMTOOL:-}" ]]; then
  "$AMTOOL" check-config "$workdir/alertmanager.yaml"
else
  docker run --rm -v "$workdir:/work:ro" --entrypoint amtool "$alertmanager_image" \
    check-config /work/alertmanager.yaml
fi
