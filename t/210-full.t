#!/usr/bin/env perl

use strict;

use Test2::V1 qw[-strict -warnings -utf8];
use Cwd qw[];
use FindBin;
use lib qq[$FindBin::RealBin/../lib];

use xmrf::app;
T2->pass(q[xmrf::app loaded successfully]);

my $suffix  = xmrf::app::cget(q[suffix]);
my $testing = qq[$FindBin::RealBin/../testing];
#my $nested  = qq[$testing/prove];

mkdir $testing || T2->bail_out(join(q[: ], q[mkdir], $testing, $!))
  unless (-d $testing);

#mkdir $nested || T2->bail_out(join(q[: ], q[mkdir], $nested, $!))
#  unless (-d $nested);

sub cleanup()
{
  unlink glob qq["$testing"/prove-*.txt];
  #unlink glob qq["$nested"/prove-*.txt];

  #rmdir $nested
  #  or T2->bail_out(join(q[: ], q[rmdir], $nested, $!));
}

sub reeeset()
{
  foreach my $c (qw[build copy execute full help named recursive verbose])
  {
    xmrf::app::cset($c => 0);
  }

  foreach my $c (qw[format match sort])
  {
    xmrf::app::cset($c => undef);
  }

  xmrf::app::cset(input  => q[.]);
  xmrf::app::cset(output => q[]);
  xmrf::app::cset(suffix => $suffix);
  xmrf::app::cset(map    => {});
}

cleanup;

open(my $fh, q[>], qq[$testing/prove-garbage-001.txt])
  or T2->bail_out(join(q[: ], q[touch], q[open], qq[$testing/prove-garbage-001.txt], $!));

close($fh)
  or T2->bail_out(join(q[: ], q[touch], q[close], qq[$testing/prove-garbage-001.txt], $!));

T01_BASIC:
{
  local @ARGV = (qw[-fe ^(.+)(prove).+?(\d+) %s%s-numeric-%01d.txt -i], $testing);

  T2->is(xmrf::app::run(), 0, q[basic run successful]);
  T2->ok(-f qq[$testing/prove-numeric-1.txt], q[basic file rename works]);

  reeeset;
}

T02_EMPTY:
{
  local @ARGV = qw(-fe (prove).+?(\d+) %s-empty-%02d.txt);
  my $cwd = Cwd::getcwd();

  T2->bail_out(join(q[: ], q[chdir], $testing, $!))
    unless chdir($testing);

  T2->is(xmrf::app::run(), 0, q[empty output run successful]);
  T2->ok(-f q[prove-empty-01.txt], q[empty output file rename works]);

  T2->bail_out(join(q[: ], q[chdir], $cwd, $!))
    unless chdir($cwd);
}

# TODO: Add more advanced testing of "full" here, but might be unrequired.

cleanup;

T2->done_testing;
