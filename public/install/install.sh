#!/bin/sh
# Configure the signed XMRF repository and install the package.
set -eu

GPG_FINGERPRINT='77EB2650F7CFEC5B6585A2FD33465E81997C2758'
REPO_URL=${XMRF_REPO_URL:-https://xmrf.taiz.me}
REPO_URL=${REPO_URL%/}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die 'Run this installer as root.'
case "$REPO_URL" in
  https://*|file:///*) ;;
  *) die 'The repository URL must use HTTPS or an absolute file:// mirror.' ;;
esac
[ -r /etc/os-release ] || die 'Cannot identify distribution.'
. /etc/os-release
manager=
for family in "${ID:-}" ${ID_LIKE:-}; do
  case "$family" in
    debian|ubuntu) manager=apt ;;
    fedora|rhel|centos|rocky|almalinux|amzn) manager=dnf ;;
    alpine) manager=apk ;;
    arch|archlinux|manjaro|endeavouros) manager=pacman ;;
  esac
  [ -z "$manager" ] || break
done
[ -n "$manager" ] || die "Unsupported distribution: ${ID:-unknown}."
command -v "$manager" >/dev/null 2>&1 || die "This distribution requires $manager."
printf 'Configuring XMRF repository for %s...\n' "${PRETTY_NAME:-$ID}"

# Bootstrap exclusively from the system's existing trusted repositories.
case "$manager" in
  apt)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends ca-certificates curl gnupg
    ;;
  dnf) dnf install -y ca-certificates curl gnupg2 ;;
  apk) apk add --no-cache ca-certificates curl gnupg ;;
  pacman)
    # Refreshing Arch's databases requires a full upgrade, not a partial one.
    pacman -Syu --needed --noconfirm ca-certificates curl gnupg
    ;;
esac

umask 077
work=$(mktemp -d)
cleanup() {
  gpgconf --homedir "$work/gnupg" --kill gpg-agent 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
mkdir "$work/gnupg"
export GNUPGHOME="$work/gnupg"
fetch() {
  curl --fail --silent --show-error --location --retry 3 \
    --connect-timeout 15 --max-time 120 --proto '=https,file' \
    --proto-redir '=https' --tlsv1.2 "$REPO_URL/$1" -o "$2"
}
fetch xmrf-signing.asc "$work/key.asc"
gpg --batch --show-keys --with-colons "$work/key.asc" > "$work/key.info"
fingerprints=$(awk -F: '
  $1 == "pub" { primary = 1; next }
  $1 == "sub" { primary = 0 }
  $1 == "fpr" && primary { print $10; primary = 0 }
' "$work/key.info")
[ "$fingerprints" = "$GPG_FINGERPRINT" ] || die 'Signing key fingerprint mismatch.'
gpg --batch --import "$work/key.asc"

case "$manager" in
  apt)
    install -d -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
    gpg --batch --yes --dearmor -o "$work/xmrf.gpg" "$work/key.asc"
    install -m 644 "$work/xmrf.gpg" /etc/apt/keyrings/xmrf.gpg
    cat > "$work/xmrf.sources" <<SOURCES
Types: deb
URIs: $REPO_URL/deb/
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/xmrf.gpg
SOURCES
    install -m 644 "$work/xmrf.sources" /etc/apt/sources.list.d/xmrf.sources
    rm -f /etc/apt/sources.list.d/xmrf.list
    apt-get update -o APT::Update::Error-Mode=any
    apt-get install -y xmrf
    ;;
  dnf)
    install -d -m 755 /etc/pki/rpm-gpg /etc/yum.repos.d
    install -m 644 "$work/key.asc" /etc/pki/rpm-gpg/RPM-GPG-KEY-XMRF
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-XMRF
    cat > "$work/xmrf.repo" <<REPOSITORY
[xmrf]
name=XMRF Package Repository
baseurl=$REPO_URL/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
skip_if_unavailable=0
sslverify=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-XMRF
REPOSITORY
    install -m 644 "$work/xmrf.repo" /etc/yum.repos.d/xmrf.repo
    dnf install --refresh -y xmrf
    rpm -V xmrf
    ;;
  apk)
    fetch xmrf-alpine.rsa.pub "$work/xmrf-alpine.rsa.pub"
    fetch xmrf-alpine.rsa.pub.asc "$work/xmrf-alpine.rsa.pub.asc"
    gpg --batch --verify "$work/xmrf-alpine.rsa.pub.asc" "$work/xmrf-alpine.rsa.pub"
    install -d -m 755 /etc/apk/keys
    install -m 644 "$work/xmrf-alpine.rsa.pub" /etc/apk/keys/xmrf-alpine.rsa.pub
    # APK appends architecture paths for both remote and local repositories.
    apk_repo="$REPO_URL/apk"
    case "$REPO_URL" in file:///*) apk_repo="${REPO_URL#file://}/apk" ;; esac
    if ! grep -Fqx "$apk_repo" /etc/apk/repositories; then
      printf '%s\n' "$apk_repo" >> /etc/apk/repositories
    fi
    apk update
    apk add xmrf
    ;;
  pacman)
    pacman-key --init
    pacman-key --add "$work/key.asc"
    pacman-key --lsign-key "$GPG_FINGERPRINT"
    install -d -m 755 /etc/pacman.d
    cat > "$work/xmrf.conf" <<REPOSITORY
[xmrf]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = $REPO_URL/arch/any
REPOSITORY
    install -m 644 "$work/xmrf.conf" /etc/pacman.d/xmrf.conf
    if ! grep -Eq '^[[:space:]]*Include[[:space:]]*=[[:space:]]*/etc/pacman.d/xmrf\.conf[[:space:]]*$' /etc/pacman.conf; then
      printf '\nInclude = /etc/pacman.d/xmrf.conf\n' >> /etc/pacman.conf
    fi
    pacman -Syu --needed --noconfirm xmrf
    pacman -Qkk xmrf
    ;;
esac
printf 'XMRF installed successfully.\n'
