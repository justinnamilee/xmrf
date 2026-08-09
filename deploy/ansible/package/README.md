# xmrf-via-github-releases.yml

## SYNOPSIS

    $ ansible-playbook --limit deb_group \
        xmrf-via-github-releases.yml

    $ ansible-playbook --limit rpm_group -e 'xmrf_rpm=1' \
        xmrf-via-github-releases.yml

## DESCRIPTION

This Ansible playbook will fetch the latest release via GitHub, download it to
a temporary file on the machine (`/tmp/xmrf.deb` or `/tmp/xmrf.rpm`), validate
its checksum, install it with either the `apt` or `dnf` Ansible module, and
finally clean up the temporary file (even if the install fails).

It does make a hard assumption that `/tmp` is available and writable by your
Ansible user with `become: false`, so just bear that in mind.

## OPTIONS

- **xmrf_rpm**

    If **defined** this will switch it from `apt` to `dnf` for the installer, and
    will cause the downloaded asset to be the `.rpm` file.

## AUTHOR

Written by Justin "Nami" Lee.

## COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.
