#!/usr/bin/env perl

package xmrf::app;

use strict;

use File::Copy   qw[];
use File::Path   qw[];
use File::Spec   qw[];
use Getopt::Long qw[];
use Pod::Usage   qw[];


## subroutine definitions

sub boolify(_);
sub configure(\%\%);
sub deconstruct(_);
sub error($;@);
sub generate(_);
sub match(_);
sub scan(_);
sub transmog($$);


## global config

my %config =
(
  #? hardcoded defaults -> env -> getopts (wins)
  build     => $ENV{XMRF_BUILD}     // 0,
  copy      => $ENV{XMRF_COPY}      // 0,
  execute   => $ENV{XMRF_EXCUTE}    // 0,
  full      => $ENV{XMRF_FULL}      // 0,
  input     => $ENV{XMRF_INPUT}     // q[.],
  named     => $ENV{XMRF_NAMED}     // 0,
  output    => $ENV{XMRF_OUTPUT}    // q[],
  recursive => $ENV{XMRF_RECURSIVE} // 0,
  suffix    => $ENV{XMRF_SUFFIX}    // q[(?<=.)\.([^.]+)$],
  verbose   => $ENV{XMRF_VERBOSE}   // 0,
  #? positional arguments (required)
  format    => undef,
  match     => undef,
  #? special config items
  help      => 0,
  map       => {}
);


## int main(void)

sub run(@)
{
  CONFIGURE:
  {
    my %option =
    (
      q[build|b!]     => \$config{build},
      q[copy|c!]      => \$config{copy},
      q[execute|e!]   => \$config{execute},
      q[full|f!]      => \$config{full},
      q[help|h+]      => \$config{help},
      q[input|i=s]    => \$config{input},
      q[named|n!]     => \$config{named},
      q[output|o=s]   => \$config{output},
      q[recursive|r!] => \$config{recursive},
      q[suffix|s=s]   => \$config{suffix},
      q[verbose|v!]   => \$config{verbose}
    );

    configure(%option, %config);
  }

  print STDERR qq[Info: Planning mode only, no changes will be made...\n]
    unless $config{execute};

  my $error = 0;

  foreach my $f (map { generate } grep { match } map { deconstruct } scan($config{input}))
  {
    my ($o, $n, $d) = ($f->{full}, join(q[], @{$f->{output}}), $f->{output}->[0]);

    printf qq[%s: '%s' -> '%s'\n], ($config{copy} ? q[cp] : q[mv]), $o, $n
      if $config{verbose};

    next
      unless $config{execute};

    my $mpe = undef;

    if (!-d $d && (!$config{build} || File::Path::make_path($d, {error => \$mpe}) == 0))
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

  return ($error > 0);
}


## subroutines

sub boolify(_)
{
  shift ? 1 : 0
}

sub configure(\%\%)
{
  my ($option, $config, %map) = @_;

  Getopt::Long::Configure(qw[bundling ignorecase_always]);

  Getopt::Long::GetOptions(%{$option}, q[map|m=s] => \%map)
    or Pod::Usage::pod2usage(-input => $0, -exitval => 2);

  Pod::Usage::pod2usage(-input => $0, -exitval => 0, -verbose => 2, -noperldoc => 1)
    if $config->{help} > 1;

  Pod::Usage::pod2usage(-input => $0, -exitval => 1)
    if $config->{help} == 1;

  error(q[Input folder must exist], qq['$config->{input}'])
    unless (-d $config->{input});

  error(q[Incorrect number of positional arguments], int(@ARGV))
    unless (@ARGV == 2);

  my ($regex, $sprintf) = @ARGV;

  $config->{match} = eval { qr/$regex/ };

  error(q[Invalid match regex given], $@)
    if ($@);

  error(q[Sprintf should be non-zero length])
    unless (length($sprintf));

  $config->{format} = $sprintf;

  $config->{$_} = boolify($config->{$_})
    for (qw[build copy execute full named recursive verbose]);

  foreach my $m (keys(%map))
  {
    my $sub = eval qq[sub { $map{$m} }];

    error(q[Can't compile given map], $m, $@)
      if ($@);

    error(q[Given map isn't a subroutine], $m, ref($sub) // q[SCALAR])
      unless (ref($sub) eq q[CODE]);

    $config->{map}->{$m} = $sub;
  }

  $config->{suffix} = eval { qr/$config->{suffix}/ };

  error(q[Invalid suffix regex given], $@)
    if ($@);

  $config->{verbose} = 1
    unless ($config->{execute});
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

sub error($;@)
{
  my ($msg, @extra) = @_;

  print STDERR join(q[: ], q[Error], $msg, @extra) . qq[\n];
  Pod::Usage::pod2usage(-input => $0, -exitval => 2);
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
  $g->{output} = [File::Spec->catpath($v, $d), $f];

  return ($g);
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
