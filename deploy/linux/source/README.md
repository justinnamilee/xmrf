# xmrf-via-github-repository.pl

## SYNOPSIS

    $ [XMRF_BASE=/prefix] xmrf-via-github-repository

## DESCRIPTION

Installs `xmrf` from its GitHub repository using the raw URLs. Grabs each file,
puts them under `/usr/loca/{bin,lib}` by default.

## ENVIRONMENT

- `XMRF_BASE`

    Optional installation prefix.  Defaults to `/usr/local`.  The executable goes
    in `$XMRF_BASE/bin` and the library in `$XMRF_BASE/lib`.

## REQUIREMENTS

- `HTTP::Tiny`

        $ cpanm -n -q HTTP::Tiny

## AUTHOR

Written by Justin "Nami" Lee.

## COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.
