# NAME

xmrf - Regex-map Rename File

# SYNOPSIS

    xmrf [options] regex sprintf

    --build     | -b          Create output directory structure as-needed.
    --copy      | -c          Use copy instead of move as the action to execute.
    --execute   | -e          Actually perform the actions, safety flag.
    --full      | -f          Pass the full path to regex, not just filename.
    --help      | -h          Show full help dialog.
    --input     | -i <dir>    Scan <dir> for files (and subdirs too with -r).
    --links     | -l          Enable following and renaming symlinks (B<don't>).
    --map       | -m <k>=<v>  Defines a subroutine <v> to run against <k>.
    --named     | -n          Use named capture groups instead of numeric.
    --output    | -o <dir>    Prepend <dir> to output file path.
    --recursive | -r          Scan subfolders of the input directory too.
    --suffix    | -s <str>    Override the default suffix extraction regex.
    --verbose   | -v          Show actions as they happen when execute on.

# DESCRIPTION

**XMRF** will rename (or copy) files based on an input dir, an output dir, a
regex, and an sprintf format.  It tries to use some sane defaults for things
that aren't provided; at least a regex and sprintf are required to modify files
on the current working directory.

This tool originated as part of another project, **fairu-chan**, but deserved
its own identity.  It was previously called **rename**, which is apt but hard
to use due to popularity.

# OPTIONS

- **-b**, **--build**

    After the full output path is generated, create the directory structure as
    required with **File::Path::make\_path**.  If in **--no-build** mode, then a
    warning will be issued and the current action will be skipped.  It will also
    warn and skip the current action if **make\_path** fails to create it.

- **-c**, **--copy**

    Use **File::Copy::copy** instead of **File::Copy::move** as the action to perform
    on the old and new paths.

- **-e**, **--execute**

    Without specifying **--execute** only the planned actions will be shown.

- **-f**, **--full**

    In **--no-full** mode (**default**) only the filename (without file extension)
    will be passed to the regex.  When the job is complete the new filename will be
    prepended with the selected output folder and the extension will be re-added.
    The output folder defaults to the input path (with subdirs if -r) if not
    provided while in this mode.

    If enabled with **--full**, then the entire path for the file and its extension
    will be passed to the regex (sometimes quite useful).  The output folder will
    default to nothing if not provided in this mode (even with -r).

- **-h**, **--help**

    Show this page.  Use **-hh** to render the entire page with **pod2usage**.

- **-i**, **--input** `dir`

    Change the folder to scan from `./` to `dir`.

- **-l**, **--links**

    By default **XMRF** skips over all symlinks (files and directories) for safety.
    This behaviour can be changed by setting **-l**.  It is not recomended and may
    have severly unexpected results.

- **-m**, **--map** `key=val`

    Each `key` is either a numeric or named captured group, and each `val` will
    be compiled as a subroutine that is given the data returned by that capture
    group.  The subroutine should further process the capture group's value and
    ultimately return what the sprintf format is expecting for that slot.

    If the **--named** flag is specified then the `key`s should match the named
    capture groups, otherwise they should be numeric (starting from zero, not one).

    Multiple **--map** flags can be included to specify more mapping subroutines.

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

    In **--no-named** mode (**default**) the regex capture groups are taken in order
    as an array.  If **--named** is specified then it is expected the regex will use
    named capture groups.  These named capture groups will be sorted with Perl's
    `sort` function when applied to the **sprintf** section.  Internally this just
    means swapping from `@{^CAPTURE}` to `%{^CAPTURE}` then applying sort to the
    keys.

    In numeric mode, for the map subroutines, a list of `0..$#{^CAPTURE}` is
    generated to pass as the keys to the map subroutines.  In named mode it's the
    sorted keys themselves.

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

- **-s**, **--suffix** `str`

    The default suffix extraction regex is lazy, taking only the shortest possible
    value, i.e. `item.tar.gz` produces `gz` as the suffix.  Supply a new regex
    with the `str` provided.  This isn't used in **--full** mode.  Default regex:

        (?<=.)\.([^.]+)$

- **-v**, **--verbose**

    Behaves much like the `cp` or `mv` verbose option.  If **--execute** isn't
    enabled then **--verbose** is forced on to show the planned actions.

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
          '%s/%s'

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
    - XMRF\_NAMED
    - XMRF\_RECURSIVE
    - XMRF\_VERBOSE

- String Environment Variables

    The following are string options you can pass by environment instead of using
    the option flags.

    - XMRF\_INPUT
    - XMRF\_OUTPUT
    - XMRF\_SUFFIX

- Special Environment Variables
    - XMRF\_DEV **(boolean)**

        Reorders the library scanner for development.

    - XMRF\_LIB **(string)**

        Skips library scanner and only checks the directory given by this variable.

# INSTALLATION

## With Debian Package

- Grab the latest `.deb` release from [XMRF GitHub](https://github.com/justinnamilee/xmrf/releases/latest).
- Use `apt` to install it (or whatever).

        $ apt install xmrf_*.deb

- Run it!

        $ xmrf

## From Repository

- Clone the repo.

        $ git clone https://github.com/justinnamilee/xmrf.git

- Make sure the version works.

        $ cd xmrf ; prove

- Put it somewhere, see `bin/xmrf` for expected library paths.

    Two parts are needed, the wrapper `bin/xmrf`, and the library
    `lib/xmrf/app.pm`.  Put the wrapper somewhere accessible via `$PATH`.
    The library can go anywhere, but the wrapper has places it will look by
    default.  Don't forget to `chmod +x` the wrapper.

# AUTHOR

Written by Justin "Nami" Lee.

# CONTRIBUTE

If you've found a bug, have an idea for an improvement, or want to suggest a
new feature, please open an issue with enough detail to help reproduce or
understand the problem / feature (such as your environment, steps to reproduce,
or example output where applicable).

If you'd like to contribute a fix or enhancement yourself, feel free to open a
pull request.

Finally, there's no **agents.md** here for a reason, Perl has wonderful
documentation, go give it a read yourself. **:)**

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
