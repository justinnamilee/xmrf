#!/bin/sh

set -eu
cd /tmp

format=${1:?Package format required}

case "$format" in
  deb)
    # Slim Debian images sometimes exclude manpages during unpacking.
    for config in /etc/dpkg/dpkg.cfg.d/*; do
      [ -f "$config" ] || continue
      sed -i '\|^[[:space:]]*path-exclude=/usr/share/man/\*[[:space:]]*$|d' "$config"
    done

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y /packages/*.deb

    dpkg --verify xmrf
    test "$(dpkg-query -W -f='${Architecture}' xmrf)" = all
    ;;
  rpm)
    dnf install -y /packages/*.rpm
    rpm -V xmrf
    test "$(rpm -q --qf '%{ARCH}' xmrf)" = noarch
    ;;
  apk)
    apk add --no-cache --allow-untrusted /packages/*.apk
    apk info -e xmrf
    ;;
  archlinux)
    pacman -Syu --noconfirm perl
    pacman -U --noconfirm /packages/*.pkg.tar.zst
    pacman -Qkk xmrf

    test "$(pacman -Qi xmrf | sed -n 's/^Architecture[[:space:]]*:[[:space:]]*//p')" = any
    set -- /packages/*.pkg.tar.zst
    expected=${1##*/}
    expected=${expected#xmrf-}
    expected=${expected%-any.pkg.tar.zst}
    installed=$(pacman -Q xmrf)
    installed=${installed#xmrf }
    installed=${installed#0:}
    test "$installed" = "$expected"
    ;;
  *) echo "Unknown format: $format" >&2; exit 1 ;;
esac

test -x /usr/bin/xmrf
test -s /usr/share/xmrf/lib/xmrf/app.pm
test -s /usr/share/man/man1/xmrf.1.gz
test -s /usr/share/doc/xmrf/copyright
test -s /usr/share/licenses/xmrf/LICENSE

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

xmrf --help > help.txt
grep -q 'Usage:' help.txt

# xmrf sends --version through help(exit => 1)
version_rc=0
xmrf --version > version.txt 2>&1 || version_rc=$?
test "$version_rc" -eq 1
grep -q '^Version: v[0-9]' version.txt

mkdir input
printf 'package smoke test\n' > input/example-001.txt
# Planning must leave the input untouched.
xmrf -i input '^example-([0-9]+)$' 'renamed-%s'
test -f input/example-001.txt
test ! -e input/renamed-001.txt
xmrf -e -i input '^example-([0-9]+)$' 'renamed-%s'
test ! -e input/example-001.txt
test "$(cat input/renamed-001.txt)" = 'package smoke test'

case "$format" in
  deb) apt-get remove -y xmrf ;;
  rpm) dnf remove -y xmrf ;;
  apk) apk del xmrf ;;
  archlinux) pacman -R --noconfirm xmrf ;;
esac

test ! -e /usr/bin/xmrf
test ! -e /usr/share/xmrf/lib/xmrf/app.pm
