# xmrf-via-github-repositories.yml

## SYNOPSIS

    $ ansible-playbook xmrf-via-github-repositories.yml

## DESCRIPTION

This Ansible playbook will fetch the latest repository information from Github.io,
set it up for a Debian or RHEL based system, then install the latest
version of `xmrf` to the system.  It tries (it's best) to guess the OS family.

If it cannot determine what system is running, it will fallback to Debian unless
otherwise instructed (see below).

## OPTIONS

- **force_deb**

    If **true** this will force it to install `apt` repository resources.

- **force_rpm**

  If **true** this will force it to install `dnf` repository resources.

## AUTHOR

Written by Justin "Nami" Lee.

## COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.
