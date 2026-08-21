#!/usr/bin/env perl

use strict;

use Test2::V1 qw[-strict -warnings -utf8];
use FindBin;
use lib qq[$FindBin::RealBin/../lib];

use xmrf::app;
T2->pass(q[xmrf::app loaded successfully]);

my $suffix  = xmrf::app::cget(q[suffix]);
my $testing = qq[$FindBin::RealBin/../testing];
my $nested  = qq[$testing/prove];

mkdir $testing || T2->bail_out(join(q[: ], q[mkdir], $testing, $!))
  unless (-d $testing);

mkdir $nested || T2->bail_out(join(q[: ], q[mkdir], $nested, $!))
  unless (-d $nested);

sub cleanup()
{
  unlink glob qq["$testing"/prove-*.txt];
  unlink glob qq["$nested"/prove-*.txt];

  rmdir $nested
    or T2->bail_out(join(q[: ], q[rmdir], $nested, $!));
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
  local @ARGV = (qw[-e ^(prove).+?(\d+) %s-numeric-%01d -i], $testing);

  T2->is(xmrf::app::run(), 0, q[basic run successful]);
  T2->ok(-f qq[$testing/prove-numeric-1.txt], q[basic file rename works]);

  reeeset;
}

T02_NAMED:
{
  local @ARGV = (qw[-ne ^(?<a1>prove).+?(?<a2>\d+) %s-named-%02d -i], $testing);

  T2->is(xmrf::app::run(), 0, q[named run successful]);
  T2->ok(-f qq[$testing/prove-named-01.txt], q[named file rename works]);

  reeeset;
}

T03_OUTPUT:
{
  local @ARGV = (qw[-eb ^(prove).+?(\d+) %s-nested-%03d -i], $testing, q[-o], $nested);

  T2->is(xmrf::app::run(), 0, q[nested run successful]);
  T2->ok(-f qq[$nested/prove-nested-001.txt], q[nested file rename works]);

  reeeset;
}

T04_RECURSE:
{
  local @ARGV = (qw[-er ^(prove).+?(\d+) %s-recurse-%04d -i], $testing);

  T2->is(xmrf::app::run(), 0, q[recursive run successful]);
  T2->ok(-f qq[$nested/prove-recurse-0001.txt], q[recursive file rename works]);

  reeeset;
}

T05_RECURSE2:
{
  local @ARGV = (qw[-er ^(prove).+?(\d+) %s-recurse-%05d -i], $testing, q[-o], $testing);

  T2->is(xmrf::app::run(), 0, q[recursive (with output) run successful]);
  T2->ok(-f qq[$testing/prove-recurse-00001.txt], q[recursive file rename works (with output dir)]);

  reeeset;
}

T06_COPIED:
{
  local @ARGV = (qw[-ec ^(prove).+?(\d+) %s-copy-%06d -i], $testing);

  T2->is(xmrf::app::run(), 0, q[copy run successful]);
  T2->ok(-f qq[$testing/prove-recurse-00001.txt], q[copy file rename works (old exists)]);
  T2->ok(-f qq[$testing/prove-copy-000001.txt], q[copy file rename works (new exists)]);

  reeeset;
}

T07_DAMAP:
{
  local @ARGV = (qw[-e ^(prove).+?(\d+) %s-map-%07d -i], $testing, q[-m], q[1=int split //, shift]);

  T2->is(xmrf::app::run(), 0, q[map run successful]);
  T2->ok(-f qq[$testing/prove-map-0000005.txt], q[map file rename works (1)]);
  T2->ok(-f qq[$testing/prove-map-0000006.txt], q[map file rename works (2)]);

  reeeset;
}

T08_SORTB:
{
  local @ARGV = qw[-e (.*) %s -s];

  T2->is(xmrf::app::run(), 0, q[empty sort run successful]);
  T2->is(xmrf::app::cget(q[sort]), 1, q[empty sort defaults to 'input' mode]);

  reeeset;
}

T09_SORTI:
{
  local @ARGV = qw[-e (.*) %s -s input];

  T2->is(xmrf::app::run(), 0, q[empty sort run successful]);
  T2->is(xmrf::app::cget(q[sort]), 1, q[empty sort defaults to 'input' mode]);

  reeeset;
}

T10_SORTO:
{
  local @ARGV = qw[-e (.*) %s -s output];

  T2->is(xmrf::app::run(), 0, q[empty sort run successful]);
  T2->is(xmrf::app::cget(q[sort]), 2, q[empty sort defaults to 'input' mode]);

  reeeset;
}

cleanup;

T2->done_testing;
