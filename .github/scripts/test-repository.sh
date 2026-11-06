#!/bin/sh
# Run inside a clean target distribution, against local or deployed repositories.
set -eu
manager=${1:?Package manager required}
mode=${2:?local or live required}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
if [ "$mode" = local ]; then
  export XMRF_REPO_URL=file:///repo
  installer=/repo/install.sh
  cmp /repo/install.sh "/repo/install-$manager.sh"
elif [ "$mode" = live ]; then
  case "$XMRF_REPO_URL" in https://*) ;; *) exit 1 ;; esac
  case "$manager" in
    apt) apt-get update; apt-get install -y ca-certificates curl ;;
    dnf) dnf install -y ca-certificates curl ;;
    apk) apk add --no-cache ca-certificates curl ;;
    pacman) pacman -Syu --needed --noconfirm ca-certificates curl ;;
    *) exit 1 ;;
  esac
  # Wait for this exact deployment, rather than accepting a cached older site.
  ready=false
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    if curl -fsSL --connect-timeout 10 --max-time 20 --proto '=https' \
      "$XMRF_REPO_URL/build-id.txt?deployment=$DEPLOYMENT_ID" -o build-id.txt && \
      [ "$(cat build-id.txt)" = "$DEPLOYMENT_ID" ]; then
      ready=true
      break
    fi
    printf 'Waiting for deployment (%s/12)...\n' "$attempt"
    sleep 5
  done
  [ "$ready" = true ] || { echo 'The expected Pages deployment is not live.' >&2; exit 1; }
  curl -fsSL --retry 3 --proto '=https' --proto-redir '=https' \
    "$XMRF_REPO_URL/install.sh?deployment=$DEPLOYMENT_ID" -o install.sh
  installer="$work/install.sh"
else
  echo 'Expected local or live mode.' >&2
  exit 1
fi
sh "$installer"
sh "$installer"  # Re-running must not duplicate sources or disable verification.
xmrf --help > help.txt
grep -q 'Usage:' help.txt
version_rc=0
xmrf --version > version.txt 2>&1 || version_rc=$?
[ "$version_rc" -eq 1 ]
grep -q '^Version: v[0-9]' version.txt
mkdir input
printf 'signed repository smoke test\n' > input/example-001.txt
xmrf -i input '^example-([0-9]+)$' 'renamed-%s'
[ -f input/example-001.txt ] && [ ! -e input/renamed-001.txt ]
xmrf -e -i input '^example-([0-9]+)$' 'renamed-%s'
[ ! -e input/example-001.txt ]
[ "$(cat input/renamed-001.txt)" = 'signed repository smoke test' ]

case "$manager" in
  apt) dpkg-query -W xmrf ;;
  dnf)
    grep -qx 'gpgcheck=1' /etc/yum.repos.d/xmrf.repo
    grep -qx 'repo_gpgcheck=1' /etc/yum.repos.d/xmrf.repo
    rpm -V xmrf
    ;;
  apk) apk info -e xmrf ;;
  pacman)
    grep -qx 'SigLevel = PackageRequired DatabaseRequired TrustedOnly' /etc/pacman.d/xmrf.conf
    pacman -Qkk xmrf
    ;;
esac
[ "$mode" = local ] || exit 0

# A successful installation is insufficient: each client must also reject
# metadata whose signature is invalid or missing. Use a fresh cache where needed.
case "$manager" in
  apt)
    sed -i 's|file:///repo|file:///bad-repo|g' /etc/apt/sources.list.d/xmrf.sources
    if apt-get update -o APT::Update::Error-Mode=any \
      -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/xmrf.sources \
      -o Dir::Etc::sourceparts=-; then
      echo 'APT accepted forged metadata.' >&2; exit 1
    fi
    ;;
  dnf)
    sed -i 's|file:///repo|file:///bad-repo|g' /etc/yum.repos.d/xmrf.repo
    dnf --disablerepo='*' --enablerepo=xmrf clean all
    if dnf --disablerepo='*' --enablerepo=xmrf --refresh makecache; then
      echo 'DNF accepted forged metadata.' >&2; exit 1
    fi
    ;;
  apk)
    printf '/bad-repo/apk\n' > bad-repositories
    mkdir bad-download
    # apk 2.x can return success from update after ignoring an untrusted local
    # index. Fetching xmrf from only that mirror must fail, even in that case.
    if apk --no-cache --repositories-file "$work/bad-repositories" \
      fetch --output "$work/bad-download" xmrf; then
      echo 'APK accepted an unsigned index.' >&2; exit 1
    fi
    ;;
  pacman)
    mkdir pacman-db
    cat > bad-pacman.conf <<CONFIG
[options]
Architecture = auto
DBPath = $work/pacman-db
GPGDir = /etc/pacman.d/gnupg
[xmrf]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = file:///bad-repo/arch/any
CONFIG
    if pacman --config "$work/bad-pacman.conf" -Syy --noconfirm; then
      echo 'Pacman accepted an unsigned database.' >&2; exit 1
    fi
    ;;
esac
printf '%s: signed install, repeat install, rename, and signature rejection passed.\n' "$manager"
