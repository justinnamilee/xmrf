
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://justinnamilee.github.io/xmrf"
KEY_ID="77EB2650F7CFEC5B6585A2FD33465E81997C2758"
KEYRING="/etc/apt/keyrings/xmrf.gpg"
SOURCE="/etc/apt/sources.list.d/xmrf.sources"

die() {
  echo "Error: $*" >&2
  exit 1
}

(( EUID == 0 )) || die "Run this installer as root."
[[ -r /etc/os-release ]] || die "Cannot identify distribution."

. /etc/os-release

SUPPORTED=false

case "$ID" in
  debian)
    (( VERSION_ID >= 13 )) && SUPPORTED=true
    ;;
  ubuntu)
    dpkg --compare-versions "$VERSION_ID" ge "24.04" &&
      SUPPORTED=true
    ;;
esac

if [[ "$SUPPORTED" != true ]]; then
  echo "Warning: $PRETTY_NAME is not officially tested."
  echo "XMRF will probably still install and work correctly."
  echo
  echo "Worst case, the unsigned packages are tested back to Debian 12 / Ubuntu 20.04..."
  echo "See: https://github.com/justinnamilee/xmrf/releases/latest"
  echo

  # Read from the terminal, not stdin (which may contain the script).
  [[ -r /dev/tty ]] ||
    die "Cannot prompt for confirmation without a terminal."

  read -r -p "Continue anyway? [Y/n] " answer < /dev/tty

  case "$answer" in
    ""|[Yy]|[Yy][Ee][Ss]) ;;
    *) echo "Installation cancelled."; exit 0 ;;
  esac
fi

echo "Configuring XMRF repository for $PRETTY_NAME..."

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg

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

gpg --batch --yes --dearmor \
  -o "$TMPDIR/xmrf.gpg" "$TMPDIR/key.asc"

install -d -m 755 /etc/apt/keyrings
install -m 644 "$TMPDIR/xmrf.gpg" "$KEYRING"

cat > "$TMPDIR/xmrf.sources" <<EOF
Types: deb
URIs: $REPO_URL/deb/
Suites: ./
Signed-By: $KEYRING
EOF

install -m 644 "$TMPDIR/xmrf.sources" "$SOURCE"

echo "Updating package indexes..."
apt-get update

echo "Installing XMRF..."
apt-get install -y xmrf

echo "XMRF installed successfully."
