# xmrf-via-git-clone

## SYNOPSIS

    $ [XMRF_DOIT=1] [XMRF_BASE=/prefix] xmrf-via-github-source

## DESCRIPTION

Installs `xmrf` from its GitHub repository. Clones the repository into
`/tmp/xmrf`, installs the executable and Perl library under `/usr/local` by
default, then removes the temporary checkout.

## ENVIRONMENT

`XMRF_DOIT`

Must be set to a **non-empty** value or the script will not run (for safety).

`XMRF_BASE`

Optional installation prefix.  Defaults to `/usr/local`.  The executable goes
in `$XMRF_BASE/bin` and the library in `$XMRF_BASE/lib`.

## AUTHOR

Written by Justin "Nami" Lee.

## COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.
