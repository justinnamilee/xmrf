#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
site=$(realpath "${1:-site}")
: "${GPG_KEY_ID:?Set the existing GPG_KEY_ID variable}"
: "${GPG_PRIVATE_KEY:?Set the existing GPG_PRIVATE_KEY secret}"
: "${APK_PRIVATE_KEY:?Set the APK_PRIVATE_KEY secret to an unencrypted RSA PEM key}"
: "${ALPINE_IMAGE:?Pinned Alpine image required}"
: "${ARCH_IMAGE:?Pinned Arch image required}"

private=$(mktemp -d)
export GNUPGHOME="$private/gnupg"
cleanup() {
  gpgconf --homedir "$GNUPGHOME" --kill gpg-agent 2>/dev/null || true
  rm -rf "$private"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
umask 077
mkdir "$GNUPGHOME"
printf '%s\n' "$GPG_PRIVATE_KEY" | gpg --batch --import
printf '%s' "${GPG_PASSPHRASE:-}" > "$private/gpg-passphrase"
printf '%s\n' "$APK_PRIVATE_KEY" > "$private/xmrf-alpine.rsa"
unset GPG_PRIVATE_KEY GPG_PASSPHRASE APK_PRIVATE_KEY

expected=$(sed -n "s/^GPG_FINGERPRINT='\([A-F0-9]*\)'$/\1/p" public/install/install.sh)
actual=$(gpg --batch --with-colons --list-secret-keys "$GPG_KEY_ID" | awk -F: '
  $1 == "sec" { primary = 1; next }
  $1 == "ssb" { primary = 0 }
  $1 == "fpr" && primary { print $10; primary = 0 }
')
[[ -n $expected && $actual == "$expected" ]] || {
  echo 'Private GPG key does not match the fingerprint pinned in install.sh.' >&2
  exit 1
}
export GPG_SIGNING_KEY=$actual
sign() {
  gpg --batch --yes --pinentry-mode loopback \
    --passphrase-file "$private/gpg-passphrase" \
    --local-user "$GPG_SIGNING_KEY" --digest-algo SHA256 "$@"
}
verify() { gpg --batch --verify "$1" "$2"; }

gpg --batch --armor --export "$GPG_SIGNING_KEY" > "$site/xmrf-signing.asc"
openssl rsa -in "$private/xmrf-alpine.rsa" -passin pass: -check -noout
openssl rsa -in "$private/xmrf-alpine.rsa" -passin pass: -pubout \
  > "$site/xmrf-alpine.rsa.pub"
sign --armor --detach-sign --output "$site/xmrf-alpine.rsa.pub.asc" "$site/xmrf-alpine.rsa.pub"
verify "$site/xmrf-alpine.rsa.pub.asc" "$site/xmrf-alpine.rsa.pub"

# RPM signatures cover the packages, and repomd.xml authenticates the index.
for package in "$site"/rpm/*.rpm; do
  rpmsign --addsign \
    --define "_gpg_name $GPG_SIGNING_KEY" \
    --define "_gpg_path $GNUPGHOME" \
    --define "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback --passphrase-file $private/gpg-passphrase" \
    "$package"
done
mkdir "$private/rpmdb"
rpm --dbpath "$private/rpmdb" --initdb
rpm --dbpath "$private/rpmdb" --import "$site/xmrf-signing.asc"
rpmkeys --dbpath "$private/rpmdb" --checksig "$site"/rpm/*.rpm
createrepo_c "$site/rpm"
sign --armor --detach-sign --output "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"
verify "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"

# Every advertised APT architecture gets a real index of the all packages.
arches='all amd64 arm64 armhf i386 ppc64el riscv64 s390x'
dist="$site/deb/dists/stable"
mkdir -p "$dist/main/binary-all"
(cd "$site/deb"; dpkg-scanpackages --multiversion pool/main /dev/null) \
  > "$dist/main/binary-all/Packages"
gzip -n -9 -c "$dist/main/binary-all/Packages" > "$dist/main/binary-all/Packages.gz"
for arch in $arches; do
  [[ $arch == all ]] && continue
  mkdir -p "$dist/main/binary-$arch"
  cp "$dist/main/binary-all/Packages" "$dist/main/binary-all/Packages.gz" "$dist/main/binary-$arch/"
done
(cd "$dist"; apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=XMRF \
  -o APT::FTPArchive::Release::Label=XMRF \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures="$arches" \
  -o APT::FTPArchive::Release::Components=main release .) > "$dist/Release"
sign --clearsign --output "$dist/InRelease" "$dist/Release"
sign --armor --detach-sign --output "$dist/Release.gpg" "$dist/Release"
gpg --batch --verify "$dist/InRelease"
verify "$dist/Release.gpg" "$dist/Release"

# Arch uses the same OpenPGP identity as APT/RPM. repo-add embeds package
# signatures; sign both generated databases explicitly using loopback pinentry.
for package in "$site"/arch/any/*.pkg.tar.zst; do
  sign --detach-sign --output "$package.sig" "$package"
  verify "$package.sig" "$package"
done
docker run --rm -v "$site/arch/any:/repo" -w /repo "$ARCH_IMAGE" \
  bash -euc 'repo-add --include-sigs --prevent-downgrade xmrf.db.tar.gz ./*.pkg.tar.zst'
for name in db files; do
  archive="$site/arch/any/xmrf.$name.tar.gz"
  sign --detach-sign --output "$archive.sig" "$archive"
  verify "$archive.sig" "$archive"
  # GitHub Pages archives must contain real files rather than repo-add symlinks.
  rm -f "$site/arch/any/xmrf.$name" "$site/arch/any/xmrf.$name.sig"
  cp "$archive" "$site/arch/any/xmrf.$name"
  cp "$archive.sig" "$site/arch/any/xmrf.$name.sig"
done
rm -f "$site"/arch/any/*.old "$site"/arch/any/*.old.sig

# Alpine authenticates the APKINDEX and its package hashes with an RSA key.
# Only the RSA key is mounted into this container; it never receives the GPG key.
cp "$site/xmrf-alpine.rsa.pub" "$private/xmrf-alpine.rsa.pub"
docker run --rm \
  -v "$site/apk/noarch:/repo" -v "$private/xmrf-alpine.rsa:/keys/xmrf-alpine.rsa:ro" \
  -v "$private/xmrf-alpine.rsa.pub:/keys/xmrf-alpine.rsa.pub:ro" \
  -w /repo "$ALPINE_IMAGE" sh -euc '
    apk add --no-cache abuild
    apk index --allow-untrusted -d "XMRF stable" -o APKINDEX.tar.gz ./*.apk
    abuild-sign -t RSA256 -k /keys/xmrf-alpine.rsa -p /keys/xmrf-alpine.rsa.pub APKINDEX.tar.gz
  '
# APK appends the host architecture to HTTPS repository URLs. The identical
# noarch payload can serve all of these native Alpine architectures.
for arch in x86_64 aarch64 armhf armv7 x86 ppc64le s390x riscv64 loongarch64; do
  cp -a "$site/apk/noarch" "$site/apk/$arch"
done
find "$site" -type d -exec chmod 755 {} +
find "$site" -type f -exec chmod 644 {} +
