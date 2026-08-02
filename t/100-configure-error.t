#!/usr/bin/env perl

use strict;

use Test2::V1 qw[-strict -warnings -utf8];
use Capture::Tiny qw[capture];
use FindBin;
use lib qq[$FindBin::RealBin/../lib];

use xmrf::app;
T2->pass(q[xmrf::app loaded successfully]);

my $suffix  = xmrf::app::cget(q[suffix]);
my $testing = qq[$FindBin::RealBin/../testing];

mkdir $testing || T2->bail_out($!)
  unless (-d $testing);

sub reeeset()
{
  foreach my $c (qw[build copy execute full help named recursive verbose])
  {
    xmrf::app::cset($c => 0);
  }

  foreach my $c (qw[format match])
  {
    xmrf::app::cset($c => undef);
  }

  xmrf::app::cset(input  => q[.]);
  xmrf::app::cset(output => q[]);
  xmrf::app::cset(suffix => $suffix);
  xmrf::app::cset(map    => {});
}

T01_EMPTY:
{
  local @ARGV = ();

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 1, q[empty @ARGV gives correct return code]);
  T2->like($sto, qr/Error: Incorrect number/, q[empty @ARGV gives correct error message]);

  reeeset;
}

T02_HELPZ:
{
  local @ARGV = qw[-h];

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 0, q[-h gives correct return code]);

  reeeset;
}

T03_RLANK:
{
  local @ARGV = (q[], q[%s]);

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };

  T2->todo(
    'bug: we allow empty regex right now' =>
      sub { T2->is($ret[0], 1, q[zero-length positionals gives correct return code]) }
  );

  T2->todo(
    'bug: we allow empty regex right now' =>
      sub { T2->like($sto, qr[Error: Regex], q[zero-length positionals gives correct error message]) }
  );

  reeeset;
}

T04_SLANK:
{
  local @ARGV = (q[.*], q[]);

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 1, q[zero-length positionals gives correct return code]);
  T2->like($sto, qr[Error: Sprintf], q[zero-length positionals gives correct error message]);

  reeeset;
}

T05_BEGEX:
{
  local @ARGV = qw[(fail %s];

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 1, q[bad regex gives correct return code]);
  T2->like($sto, qr[Error: Invalid match], q[bad regex gives correct error message]);

  reeeset;
}

T06_BAMAP:
{
  local @ARGV = qw[(good) %s -m fail=FAKE];

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 1, q[bad map gives correct return code]);
  T2->like($sto, qr[Error: Can't compile given map], q[bad map gives correct error message]);

  reeeset;
}

T07_SUFER:
{
  local @ARGV = qw[(good) %s -s (fail];

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };
  T2->is($ret[0], 1, q[bad suffix gives correct return code]);
  T2->like($sto, qr[Error: Invalid suffix], q[bad suffix gives correct error message]);

  reeeset;
}

T2->done_testing;
