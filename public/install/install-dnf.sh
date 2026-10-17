
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://xmrf.taiz.me"
KEY_ID="77EB2650F7CFEC5B6585A2FD33465E81997C2758"
KEYFILE="/etc/pki/rpm-gpg/RPM-GPG-KEY-XMRF"
SOURCE="/etc/yum.repos.d/xmrf.repo"

die() {
  echo "Error: $*" >&2
  exit 1
}

(( EUID == 0 )) || die "Run this installer as root."
[[ -r /etc/os-release ]] || die "Cannot identify distribution."
command -v dnf >/dev/null 2>&1 ||
  die "This installer requires DNF."

. /etc/os-release

SUPPORTED=false

case "$ID" in
  fedora)
    if [[ "${VERSION_ID:-}" =~ ^[0-9]+$ ]] &&
       (( VERSION_ID >= 43 )); then
      SUPPORTED=true
    fi
    ;;
  rocky)
    if [[ "${VERSION_ID:-}" =~ ^[0-9]+(\.[0-9]+)?$ ]] &&
       (( ${VERSION_ID%%.*} >= 10 )); then
      SUPPORTED=true
    fi
    ;;
  amzn)
    if [[ "${VERSION_ID:-}" =~ ^[0-9]+(\.[0-9]+)*$ ]] &&
       (( ${VERSION_ID%%.*} >= 2023 )); then
      SUPPORTED=true
    fi
    ;;
esac

if [[ "$SUPPORTED" != true ]]; then
  echo "Warning: ${PRETTY_NAME:-Unknown Linux} is not officially tested."
  echo "XMRF will probably till install and work correctly."
  echo
  echo "Worst case, the unsigned packages are tested back to Rocky 9 / Fedora 38..."
  echo "See: https://github.com/justinnamilee/xmrf/releases/latest"

  [[ -r /dev/tty ]] ||
    die "Cannot prompt for confirmation without a terminal."

  read -r -p "Continue anyway? [Y/n] " answer < /dev/tty

  case "$answer" in
    ""|[Yy]|[Yy][Ee][Ss]) ;;
    *) echo "Installation cancelled."; exit 0 ;;
  esac
fi

echo "Configuring XMRF repository for $PRETTY_NAME..."

dnf install -y ca-certificates curl gnupg2

umask 077
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

curl -fsSL --proto '=https' --tlsv1.2 \
  "$REPO_URL/xmrf-signing.asc" \
  -o "$TMPDIR/key.asc"

# Validate the signing key before trusting it.
mapfile -t FINGERPRINTS < <(
  gpg --batch --show-keys --with-colons "$TMPDIR/key.asc" |
  awk -F: '
    $1 == "pub" { primary = 1; next }
    $1 == "sub" { primary = 0 }
    $1 == "fpr" && primary { print $10; primary = 0 }
  '
)

[[ ${#FINGERPRINTS[@]} -eq 1 &&
   "${FINGERPRINTS[0]}" == "$KEY_ID" ]] ||
  die "Signing key fingerprint mismatch."

# Install public key and import into RPM's key database.
install -d -m 755 /etc/pki/rpm-gpg
install -m 644 "$TMPDIR/key.asc" "$KEYFILE"

rpm --import "$KEYFILE"

# Configure repository.
cat > "$TMPDIR/xmrf.repo" <<EOF
[xmrf]
name=XMRF Package Repository
baseurl=$REPO_URL/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=file://$KEYFILE
EOF

install -m 644 "$TMPDIR/xmrf.repo" "$SOURCE"

echo "Installing XMRF..."
dnf install -y xmrf

rpm -V xmrf

echo "XMRF installed successfully."
