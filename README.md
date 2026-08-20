# <img alt="xmrf" src=".github/public/xmrf-banner.svg" width="770" height="64">

[![Release: Latest](https://img.shields.io/github/v/release/justinnamilee/xmrf)](https://github.com/justinnamilee/xmrf/releases/latest)
[![Build: Status](https://img.shields.io/github/actions/workflow/status/justinnamilee/xmrf/release.yml)](https://github.com/justinnamilee/xmrf/actions/workflows/release.yml)
&emsp;
[![Language: Perl](https://img.shields.io/badge/Language-Perl-blue.svg)](https://perl.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

_Your friendly neighborhood file-sorting tool—now with more brimstone._

---
# NAME

XMRF - Regex-map Rename File, advanced command-line file management utiltity.

# SYNOPSIS

    $ xmrf [options] regex sprintf

    --build     | -b          Create output directory structure as-needed.
    --copy      | -c          Use copy instead of move as the action to execute.
    --execute   | -e          Actually perform the actions, safety flag.
    --full      | -f          Pass the full path to regex, not just filename.
    --help      | -h          Show full help dialog.
    --input     | -i <dir>    Scan <dir> for files (and subdirs too with -r).
    --links     | -l          Enable following and renaming symlinks (don't).
    --map       | -m <k>=<v>  Defines a subroutine <v> to run against <k>.
    --named     | -n          Use named capture groups instead of numeric.
    --output    | -o <dir>    Prepend <dir> to output file path.
    --recursive | -r          Scan subfolders of the input directory too.
    --sort      | -s [str]    Sort, optionally with in a specific way.
    --suffix         <str>    Override the default suffix extraction regex.
    --verbose   | -v          Show actions as they happen when execute on.
    --version                 Show the version number of xmrf.

# DESCRIPTION

**XMRF** will rename (or copy) files based on an input dir, an output dir, a
regex, and an sprintf format.  It tries to use some sane defaults for things
that aren't provided; at least a regex and sprintf are required to modify files
in the current working directory.

This tool uses only core modules, nothing extra required from
[CPAN](https://www.cpan.org/).

# OPTIONS

All boolean option flags (flags that take no value) default to their
**--no-_flag_** variant.

- **-b**, **--build**

    After the full output path is generated, create the directory structure as
    required with **File::Path::make\_path**.  If in **--no-build** mode and the full
    output directory structure is not already existing, then a warning will be
    issued and the current action will be skipped.  It will also warn and then skip
    the current action if **make\_path** fails to create the missing directory
    structure elements.

- **-c**, **--copy**

    Use **File::Copy::copy** instead of **File::Copy::move** as the action to perform
    on the old and new paths.

- **-e**, **--execute**

    Without specifying **--execute** only the planned actions will be shown, no
    changes will be made.

- **-f**, **--full**

    In **--no-full** mode only the filename (without file extension) will be passed
    to the regex.  When the job is complete the new filename will be prepended with
    the selected output folder and the extension will be re-added. The output
    folder defaults to the input path (with subdirs if -r) if not provided while in
    this mode.

    If enabled with **--full**, then the entire path for the file and its extension
    will be passed to the regex (sometimes quite useful).  The output folder will
    default to nothing if not provided in this mode (even with -r).

- **-h**, **--help**

    Show this page.  Use **-hh** to render the complete POD with **pod2usage**.  If
    installed with a packaged version `man xmrf` should work as well.

- **-i**, **--input** `dir`

    Change the folder to scan from `./` to `dir`.

- **-l**, **--links**

    By default **XMRF** skips over all symlinks (files and directories) for safety.
    This behaviour can be changed by setting **--links**.  It is not recomended and
    may have severly unexpected results.

    Note that this doesn't apply to paths with symlinks in them provided as the
    input folder, it just prevents the directory scanner from adding files that
    are symlinks or scanning subfolders that are symlinks in recursive mode.  For
    example:

        $ ls -l
        lrwxrwxrwx 1 user user 1 Jan 01 2026 Documents -> /mnt/remote/Documents

    XMRF is more than happy to accept this symlinked folder as its input
    folder.  However, if this `Documents` symlink contains further symlinks
    within itself, then those would be skipped by default.

- **-m**, **--map** `key=val`

    Multiple **--map** flags can be included to specify more mapping subroutines.

    Each `key` is either a numeric (**--no-named**) or named (**--named**) captured
    group, and each `val` will be compiled as a subroutine that is given the data
    returned by that capture group.  The subroutine should further process the
    capture group's value and ultimately return what the sprintf format is
    expecting for that slot.

    **NOTE:** Ensure you lexically scope any variables that are declared with `my`.
    If needed, the global `%config` is available to reference (or modify should
    decreased sanity be desired).

    If the **--named** flag is specified then the `key`s should match the named
    capture groups, otherwise they should be numeric (indexed from **zero**, not
    one).  You only have to specify maps for desired keys, not all (in case this
    isn't obvious).  Named mode can be useful for specifying the order in which
    the output should be populated without needing to resort to `sprintf`'s
    [format parameter index](https://perldoc.perl.org/functions/sprintf#format-parameter-index).

         numeric regex: (\d\d).+\[(\w+?)\]          maps: 0='1 + shift', 1='uc shift'
           named regex: (?<b>\d\d).+\[(?<a>\w+?)\]  maps: a='uc shift', b='1 + shift'

        numeric format: %2$s-%1$02d
          named format: %s-%02d

    As a quick example (see **EXAMPLES**), let's add the date to all files in the
    current directory:

        $ xmrf '^(.+)()' '%s-%s' -m \
         1='my ($d,$m,$y)=(localtime)[3..5]; sprintf(q[%d-%02d-%02d],$y+1900,$m+1,$d)'

        Info: Planning mode only, no changes will be made...
        mv: './.gitignore' -> './.gitignore-2026-08-06'
        mv: './LICENSE' -> './LICENSE-2026-08-06'

    So using an empty capture group additional data can be inserted into the output
    using a subroutine.  It may be desirable to modify actual capture data too,
    it will be passed as the first argument to the subroutine (`$_[0]`):

        $ xmrf '^(.+)()' '%s-%s' -m \
         0='uc shift'            -m \
         1='my ($d,$m,$y)=(localtime)[3..5]; sprintf(q[%d-%02d-%02d],$y+1900,$m+1,$d)'

        Info: Planning mode only, no changes will be made...
        mv: './.gitignore' -> './.GITIGNORE-2026-08-06'
        mv: './LICENSE' -> './LICENSE-2026-08-06'

    For brevity `shift` was used, but `$_[0]` works as well, obviously (and may
    be required for more complex situations).

- **-n**, **--named**

    In **--no-named** mode the regex capture groups are taken in order as an array.
    If **--named** is specified then it is expected the regex will use named capture
    groups.  These named capture groups will be sorted with Perl's `sort` function
    when applied to the **sprintf** section.  Internally this just means swapping
    from `@{^CAPTURE}` to `%{^CAPTURE}` then applying `sort` to the keys.

    In numeric mode (**--no-named**), for the map subroutines, a list of
    `0..$#{^CAPTURE}` is generated to pass as the keys to the map subroutines.
    In named mode it's the sorted keys themselves.

- **-o**, **--output** `dir`

    The **--output** flag, if supplied, will be prepended to the output file from
    the **format** argument.  In **--no-full** mode, if unspecified, it defaults to
    the **--input** folder (with subdirs if -r).  In **--full** mode it defaults to
    nothing (even with -r).  **File::Spec** will clean up this path as it sees fit.

    Note that the output flag can often be omitted in **--full** mode, as it's
    possible (maybe preferable) to include the output path right in the **sprintf**
    like so:

        $ xmrf -f '.+/(.+?)$' /new/path/to/'%s'

    While contrived, this example is equivalent to `mv * /new/path/to`, or:

        $ xmrf -fo /new/path/to '.+/(.+?)$' '%s'

    This idea can also be used to insert some relative paths as well, like:

        $ xmrf '(.+)' relative/path/'%s'

    Which would produce paths like `./relative/path`, because in **--no-full** mode
    the output option would be set to `./` (same as input) if not provided.

    These concepts can be mixed and matched to best suit the goals of the actions
    desired.

- **-r**, **--recursive**

    If set the input folder and all its subfolders will be scanned for files.

- **-s**, **--sort** `[str]`

    This flag will enable sorting by the input or output file paths.  The default,
    if the optional `[str]` is not provided, empty, or explicitly set to `input`,
    is by the input paths.  If the optional `[str]` is set to `output` then the
    final resulting file paths will be sorted instead.

    If in **--no-sort** mode, then however the underlying file system returns data
    to the [readdir](https://perldoc.perl.org/functions/readdir) call is how the
    files will be actioned.

    - `--no-sort`, default, however files are returned by file system
    - `--sort`, `--sort ''`, `--sort 'input'`, sort by input from `readdir`
    - `--sort 'output'`, sort by final output paths after work is complete

- **--suffix** `str`

    The default suffix extraction regex is lazy, taking only the shortest possible
    value, i.e. `item.tar.gz` produces `gz` as the suffix.  Supply a new regex
    with the `str` provided.  This isn't used in **--full** mode.  Default regex:

        (?<=.)\.([^.]+)$

- **-v**, **--verbose**

    Behaves much like the `cp` or `mv` verbose option.  If **--execute** isn't
    enabled then **--verbose** is forced on to show the planned actions.

- **--version**

    Show the current version number of XMRF, note that any addition of the
    **--help** option flag will override this.

# EXAMPLES

## BASIC

- Fix a Long-Standing Typo

        $ xmrf -ri /media '^(.+)HVEC(.+)' '%sHEVC%s'

    This keeps everything the same, but fixes a typo in place.

- Old-School Backups to Modern

        $ xmrf -i /media/backup/show '_(\d+)x(\d+)_' \
          '[DVD Backup] Show - S%02dE%02d [480p]'

    Back in the day when we backed up our DVDs we used `x` between a season
    number and episode.

- Make CRC32s More Appealing

        $ xmrf -i /media/backup/anime ' (\d+(?:v\d)?) .+\[(.+?)\]' \
          '[BluRay Backup] Anime - S01E%s [1080p][%s]' \
          -m 1='uc shift'

    Nothing worse than a CRC32 in lowercase.  This one uses a small map-subroutine
    on the second capture group.

## ADVANCED

- A Brain Teaser

        $ xmrf -bi ~/Input -o ~/Output \
          '^(\[[\]]+\] (.+?)(?:\.+)?(?: (?:- )?\d+(?i: ?v\d+)?)? (?:\(|\[).+)$' \
          '%2$s/%1$s'

    This one inspired [fairu-chan](https://github.com/justinnamilee/fairu-chan).

# ENVIRONMENT

**XMRF** also accepts some options by environment variable.  When loading,
options passed by command-line flag will override anything passed by
environment (except for `XMRF_DEV` and `XMRF_LIB`).

- Boolean Environment Variables

    The following are boolean (0 or 1) options you can pass by environment instead
    of using the option flags.

    - XMRF\_BUILD
    - XMRF\_COPY
    - XMRF\_EXECUTE
    - XMRF\_FULL
    - XMRF\_LINKS
    - XMRF\_NAMED
    - XMRF\_RECURSIVE
    - XMRF\_VERBOSE

- String Environment Variables

    The following are string options you can pass by environment instead of using
    the option flags.

    - XMRF\_INPUT
    - XMRF\_OUTPUT
    - XMRF\_SORT (_can be empty, see **--sort**_)
    - XMRF\_SUFFIX

- Special Environment Variables
    - XMRF\_DEV **(boolean)**

        Reorders the library scanner for development.

    - XMRF\_LIB **(string)**

        Skips library scanner and only checks the directory given by this variable.

# INSTALLATION

More options are available in the [deploy folder](https://github.com/justinnamilee/xmrf/tree/main/deploy).

## Packaged Release

Grab the latest `.exe`, `.deb`, or `.rpm` release from [XMRF GitHub](https://github.com/justinnamilee/xmrf/releases/latest).
Once downloaded, `apt` or `dnf` can install it locally to the system, use
whichever is appropriate for the system.  The Windows `.exe` is ready to go
out of the box, just put it in the `%PATH%`.

## Manual Installation

Clone the repository.  Put the wrapper script somewhere (say
`/usr/local/bin/xmrf`).  Put the library somewhere (say
`/usr/local/lib/xmrf/app.pm`).  Set the execute bit on the wrapper.

    $ git clone 'https://github.com/justinnamilee/xmrf'
    $ cd xmrf
    $ sudo cp bin/xmrf /usr/local/bin/xmrf
    $ sudo cp lib/xmrf/app.pm /usr/local/lib/xmrf/app.pm
    $ sudo chmod 644 /usr/local/lib/xmrf/app.pm
    $ sudo chmod 755 /usr/local/bin/xmrf
    $ xmrf --version

# TESTING

After cloning the repository, testing is fairly simple.  Both **[Test2::V1](https://metacpan.org/pod/Test2%3A%3AV1)**
and **[Capture::Tiny](https://metacpan.org/pod/Capture%3A%3ATiny)** are required:

    $ cpanm -n -q Test2::V1 Capture::Tiny

Then it's as simple as running prove on the directory:

    $ prove -lv

# AUTHOR

Written by Justin "Nami" Lee.

# CONTRIBUTE

If you've found a bug, have an idea for an improvement, or want to suggest a
new feature, please open an issue with enough detail to help reproduce or
understand the problem / feature (such as your environment, steps to reproduce,
or example output where applicable).

If you'd like to contribute a fix or enhancement yourself, feel free to open a
pull request.

# HISTORY

This tool originated as part of another project, **fairu-chan**, but deserved
its own identity.  It was previously called **rename**, which is apt but hard
to use due to popularity.

- April 16, 2018

    The first one-liner uploaded to GitHub Gists as [rename.pl](https://gist.github.com/justinnamilee/5f3d757beb3f63ba863b0877b790128c).

        opendir(my $d, '.'); my @d = grep { -f } readdir($d); \
        print @d . qq( files found:\n); foreach my $o (@d) {  \
        if ($o =~ /x(\d\d)\s+-\s+(.+)/) { my $n =             \
        sprintf(qq(S09E%02d-E%02d %s), $1*2 -1, $1*2, $2);    \
        print qq($o\n\t$n\n); rename($o, $n) or warn $!; } }

- May 6, 2024

    The script moves into [fairu-chan](https://github.com/justinnamilee/fairu-chan/commit/6d8aab629910ba0400596705860d36075e64c0fd).

- July 13, 2026

    A [new repository](https://github.com/justinnamilee/xmrf) dedicated to the tool is started.

# COPYRIGHT

Copyright © 2026 Justin "Nami" Lee.  License [GPLv3+](https://gnu.org/licenses/gpl.html):
GNU GPL version 3 or later.  This is free software: you are free to change and
redistribute it.  There is **NO WARRANTY**, to the extent permitted by law.

# SEE ALSO

- [perlre](https://perldoc.perl.org/perlre)
- [sprintf](https://perldoc.perl.org/functions/sprintf)
- [perlsub](https://perldoc.perl.org/perlsub)
- [xmrf](https://github.com/justinnamilee/xmrf)
- [fairu-chan](https://github.com/justinnamilee/fairu-chan)
