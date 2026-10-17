# <img alt="xmrf" src="public/img/xmrf-banner.svg" width="770" height="64">

[![Release: Latest](https://img.shields.io/github/v/release/justinnamilee/xmrf)](https://github.com/justinnamilee/xmrf/releases/latest)
[![Build: Status](https://img.shields.io/github/actions/workflow/status/justinnamilee/xmrf/release.yml)](https://github.com/justinnamilee/xmrf/actions/workflows/release.yml)
&emsp;
[![Language: Perl](https://img.shields.io/badge/Language-Perl-blue.svg)](https://perl.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

_Your friendly neighborhood file-sorting tool—now with more brimstone._

---

# INSTALLATION

See the [repository page](https://justinnamilee.github.io/xmrf/) for details, or just run one of these...

- Debian / Ubuntu Based:

      curl -fsSL https://justinnamilee.github.io/xmrf/install-apt.sh | sudo bash

- Fedora / RHEL Based:

      curl -fsSL https://justinnamilee.github.io/xmrf/install-dnf.sh | sudo bash

### Ansible

There's Ansible playbooks for installing [via Releases](https://github.com/justinnamilee/xmrf/tree/main/public/deploy/ansible/package),
or [via Repository](https://github.com/justinnamilee/xmrf/tree/main/public/deploy/ansible/respository).

### Packaged Release

Grab the latest `.exe`, `.deb`, or `.rpm` release from [XMRF GitHub](https://github.com/justinnamilee/xmrf/releases/latest).
The Windows `.exe` is ready to go out of the box, just put it in the `%PATH%`.
**Note the packaged versions are unsigned.**

### Manual Installation

    $ git clone 'https://github.com/justinnamilee/xmrf'
    $ cd xmrf
    $ sudo install -Dm755 bin/xmrf /usr/local/bin/xmrf
    $ sudo install -Dm644 lib/xmrf/app.pm /usr/local/lib/xmrf/app.pm
    $ xmrf --version

# TESTING

After cloning the repository, testing is fairly simple.  Both **[Test2::V1](https://metacpan.org/pod/Test2%3A%3AV1)**
and **[Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny)** are required:

    $ cpanm -n -q Test2::V1 Capture::Tiny

Then it's as simple as running prove on the directory:

    $ prove -lv

---
