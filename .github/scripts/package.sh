#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

tag=${1:?Usage: package.sh vMAJOR.MINOR.PATCH[-alpha-N|-beta-N]}
if [[ ! $tag =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)(-(alpha|beta)-([0-9]+))?$ ]]; then
  echo "Unsupported release version: $tag" >&2
  exit 1
fi
export XMRF_VERSION=${BASH_REMATCH[1]}
# Alpine uses _beta1, rather than SemVer's -beta-1. nFPM applies each
# format's separator; a shared beta1/alpha1 suffix works in all four.
export XMRF_PRERELEASE=${BASH_REMATCH[3]}${BASH_REMATCH[4]}
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}

mkdir -p .packaging dist
pod2man bin/xmrf --center="Regex-map File Rename" --section=1 \
  --release="$tag" | gzip -n -9 > .packaging/xmrf.1.gz

for format in deb rpm apk archlinux; do
  nfpm package --config nfpm.yaml --packager "$format" --target dist/
done
