#!/usr/bin/env bash
set -euo pipefail
manager=${1:?Package manager required}
mode=${2:?local or live required}
case "$manager" in
  apt) image=$DEBIAN_IMAGE ;;
  dnf) image=$FEDORA_IMAGE ;;
  apk) image=$ALPINE_IMAGE ;;
  pacman) image=$ARCH_IMAGE ;;
  *) echo "Unknown manager: $manager" >&2; exit 1 ;;
esac
mounts=()
if [[ $mode == local ]]; then
  mounts=(-v "$PWD/site:/repo:ro" -v "$PWD/bad-site:/bad-repo:ro")
fi
docker run --rm "${mounts[@]}" \
  -v "$PWD/.github/scripts/test-repository.sh:/test-repository.sh:ro" \
  -e "XMRF_REPO_URL=${XMRF_REPO_URL:-}" -e "DEPLOYMENT_ID=${DEPLOYMENT_ID:-}" \
  "$image" sh /test-repository.sh "$manager" "$mode"
