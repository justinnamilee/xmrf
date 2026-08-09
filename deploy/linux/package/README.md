# xmrf-via-github-releases.pl

## SYNOPSIS

    $ xmrf-via-github-releases

## DESCRIPTION

This Perl script will fetch the latest release via GitHub, download it to
a temporary file on the machine (`/tmp/xmrf.deb` or `/tmp/xmrf.rpm`), validate
its checksum, install it with either the `apt` or `dnf` system tool, and
finally clean up the temporary file (even if the install fails).

It does make a hard assumption that `/tmp` is available and writable by the
current user, so just bear that in mind.

If current user is not `root`, it will automatically try `sudo`.

## REQUIREMENTS

- **Digest::SHA**

    Used to calculate and check the SHA256 checksum against what GitHub says.

        $ cpam -n -q Digest::SHA

- **HTTP::Tiny**

    Used to check the API, download the file, etc.

        $ cpanm -n -q HTTP::Tiny

## AUTHOR

Written by Justin "Nami" Lee.

## COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.
