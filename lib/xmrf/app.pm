#!/usr/bin/env perl

package xmrf::app v1.2.1;


use strict;

use File::Copy   qw[];
use File::Path   qw[];
use File::Spec   qw[];
use Getopt::Long qw[];
use Pod::Usage   qw[];


## function definitions

sub boolify(_);
sub cget($);
sub configure(\%\%);
sub cset($$);
sub deconstruct(_);
sub generate(_);
sub help($;$@);
sub match(_);
sub scan(_);
sub transmog($$);


## global config

my %config =
(
  #? hardcoded defaults -> env -> getopts (wins)
  build     => $ENV{XMRF_BUILD}     // 0,
  copy      => $ENV{XMRF_COPY}      // 0,
  execute   => $ENV{XMRF_EXECUTE}   // 0,
  full      => $ENV{XMRF_FULL}      // 0,
  input     => $ENV{XMRF_INPUT}     // q[.],
  links     => $ENV{XMRF_LINKS}     // 0,
  named     => $ENV{XMRF_NAMED}     // 0,
  output    => $ENV{XMRF_OUTPUT}    // q[],
  recursive => $ENV{XMRF_RECURSIVE} // 0,
  sort      => $ENV{XMRF_SORT}      // undef,
  suffix    => $ENV{XMRF_SUFFIX}    // q[(?<=.)\.([^.]+)$],
  verbose   => $ENV{XMRF_VERBOSE}   // 0,
  #? positional arguments (required)
  format    => undef,
  match     => undef,
  #? special config items
  help      => 0,
  map       => {},
  version   => 0
);


## int main(void)

sub run(;$)
{
  my ($noconf) = @_;

  unless ($noconf)
  {
    my %option =
    (
      q[build|b!]     => \$config{build},
      q[copy|c!]      => \$config{copy},
      q[execute|e!]   => \$config{execute},
      q[full|f!]      => \$config{full},
      q[help|h+]      => \$config{help},
      q[input|i=s]    => \$config{input},
      q[links|l!]     => \$config{links},
      q[named|n!]     => \$config{named},
      q[output|o=s]   => \$config{output},
      q[recursive|r!] => \$config{recursive},
      q[sort|s:s]     => \$config{sort},
      q[suffix=s]     => \$config{suffix},
      q[verbose|v!]   => \$config{verbose},
      q[version]      => \$config{version}
    );

    my $c = configure(%option, %config);

    return $c
      unless $c == -1;
  }

  print STDERR qq[Info: Planning mode only, no changes will be made...\n]
    unless $config{execute};

  my $error = 0;

  foreach my $f
  (
    sort { $config{sort} == 2 && qq[\F$a->{output}->{path}] cmp qq[\F$b->{output}->{path}] }
      map { generate }
        grep { match }
          map { deconstruct }
            sort { $config{sort} == 1 && qq[\F$a] cmp qq[\F$b] } #? no fc
              scan($config{input})
  )
  {
    my ($o, $n, $d) = ($f->{full}, $f->{output}->{path}, $f->{output}->{dir});

    printf qq[%s: '%s' -> '%s'\n], ($config{copy} ? q[cp] : q[mv]), $o, $n
      if $config{verbose};

    next
      unless $config{execute};

    my $mpe = undef;

    if (length($d) && !-d $d && (!$config{build} || File::Path::make_path($d, {error => \$mpe}) == 0))
    {
      warn qq[Warning: '$d' does not exist (or can't create), skipping...\n];

      $error++;
      next;
    }

    unless ($config{copy} ? File::Copy::copy($o, $n) : File::Copy::move($o, $n))
    {
      warn qq[Warning: Failed to process, $!...\n];

      $error++;
    }
  }

  return boolify($error > 0);
}


## subroutines

sub boolify(_)
{
  shift ? 1 : 0
}

sub cget($)
{
  my ($c) = @_;
  $config{$c}
}

sub configure(\%\%)
{
  my ($option, $config, %map) = @_;

  Getopt::Long::Configure(qw[bundling ignorecase_always]);

  return help(0, 1, q[Error], q[Failed parsing given options])
    unless Getopt::Long::GetOptions(%{$option}, q[map|m=s] => \%map);

  return help($config->{help} > 1 ? 2 : 1)
    if $config->{help} > 0;

  return help(0, 1, q[Version], our $VERSION)
    if ($config->{version});

  return help(0, 1, q[Error], q[Input folder must exist], qq['$config->{input}'])
    unless (-d $config->{input});

  return help(0, 1, q[Error], q[Incorrect number of positional arguments], int(@ARGV))
    unless (@ARGV == 2);

  my ($regex, $sprintf) = @ARGV;

  return help(0, 1, q[Error], q[Regex should be non-zero length])
    unless (length($regex));

  $config->{match} = eval { qr/$regex/ };

  return help(0, 1, q[Error], q[Invalid match regex given], $@)
    if ($@);

  return help(0, 1, q[Error], q[Sprintf should be non-zero length])
    unless (length($sprintf));

  $config->{format} = $sprintf;

  $config->{$_} = boolify($config->{$_})
    for (qw[build copy execute full links named recursive verbose version]);

  foreach my $m (keys(%map))
  {
    my $sub = eval qq[sub { $map{$m} }];

    return help(0, 1, q[Error], q[Can't compile given map], $m, $@)
      if ($@);

    $config->{map}->{$m} = $sub;
  }

  $config->{sort} = lc($config->{sort})
    if length($config->{sort});

  return help(0, 1, q[Error], q[Invalid sort mode provided], $config->{sort})
    if (length($config->{sort}) && !($config->{sort} eq q[input] || $config->{sort} eq q[output]));

  $config->{sort} = defined($config->{sort})
    ? length($config->{sort}) && $config->{sort} eq q[output]
      ? 2 # output sort mode
      : 1 # input sort mode
    : 0;  # no sort mode (however FS returns data)

  $config->{suffix} = eval { qr/$config->{suffix}/ };

  return help(0, 1, q[Error], q[Invalid suffix regex given], $@)
    if ($@);

  $config->{verbose} = 1
    unless ($config->{execute});

  return -1;
}

sub cset($$)
{
  my ($c, $v) = @_;
  $config{$c} = $v
}

sub deconstruct(_)
{
  my ($path, $e) = @_;
  my ($v, $d, $f) = File::Spec->splitpath($path);

  if ($f =~ s/$config{suffix}//)
  {
    $e = $1;
  }

  return
  ({
    ext  => $e // q[],
    file => $f,
    full => $path,
    path => File::Spec->catpath($v, $d),
  });
}

sub generate(_)
{
  my ($g) = @_;

  my $output = sprintf($config{format}, @{$g->{match}});

  if ($config{full} && length($config{output}))
  {
    $output = File::Spec->join($config{output}, $output);
  }
  elsif (length($config{output}))
  {
    $output = join
    (
      q[.],
      File::Spec->join($config{output}, $output),
      grep { length } $g->{ext}
    )
  }
  elsif (!$config{full})
  {
    $output = join
    (
      q[.],
      File::Spec->join($g->{path}, $output),
      grep { length } $g->{ext}
    )
  }

  my ($v, $d, $f) = File::Spec->splitpath($output);

  $g->{output} =
  {
    dir  => File::Spec->catpath($v, $d),
    file => $f,
    path => $output
  };

  return ($g);
}

sub help($;$@)
{
  my ($verbose, $exit, @msg) = @_;

  #*EXE POD*#

  Pod::Usage::pod2usage
  (
    -input => $0,
    -exitval => 'NOEXIT',
    -verbose => $verbose,
    -noperldoc => 1,
    (@msg ? (-msg => join(q[: ], @msg)) : ())
  );

  return ($exit ? int($exit) : 0);
}

sub match(_)
{
  my ($f) = @_;

  if ($f->{$config{full} ? q[full] : q[file]} =~ $config{match})
  {
    $f->{match} =
    [
      $config{named}
        ? (map { transmog($_, ${^CAPTURE{$_}}) } sort keys %{^CAPTURE})
        : (map { transmog($_, ${^CAPTURE[$_]}) } 0 .. $#{^CAPTURE})
    ];
  }

  return (ref($f->{match}));
}

sub scan(_) #? who needs file::find
{
  my ($path, @f) = @_;

  if (-f $path)
  {
    push(@f, $path);
  }
  elsif (-d $path)
  {
    if (opendir(my $dh, $path))
    {
      foreach my $i (grep { !/^\.\.?$/ } readdir($dh))
      {
        my $p = File::Spec->join($path, $i);

        next if -l $p && !$config{links};

        push(@f, -f $p ? $p : (-d $p && $config{recursive} ? scan($p) : ()));
      }
    }
    else
    {
      warn qq[Unable to open directory: '$path': $!\n];
    }
  }

  return (@f);
}

sub transmog($$)
{
  my ($k, $v) = @_;

  return (exists($config{map}->{$k}) ? $config{map}->{$k}->($v) : $v);
}


__PACKAGE__
