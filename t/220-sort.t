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

my $limit = 16; #? set the number of files to gen

mkdir $testing || T2->bail_out(join(q[: ], q[mkdir], $testing, $!))
  unless (-d $testing);

sub cleanup()
{
  unlink glob qq["$testing"/prove-*.txt];
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

sub touch($)
{
  my ($f) = @_;

  open(my $fh, q[>], $f)
    or T2->bail_out(join(q[: ], q[touch], q[open], $f, $!));

  close($fh)
    or T2->bail_out(join(q[: ], q[touch], q[close], $f, $!));

  return 1;
}

touch(qq[$testing/prove-garbage-$_.txt])
  foreach 1 .. $limit;

T01_SORTI:
{
  local @ARGV =
  (
    qw[^prove-().+?-(\d+) prove-%02d-sort-%d --sort input -i], $testing,
    q[-m], q[0=use feature q(state); state $x = 99; $x--] #? force rev sort
  );

  T2->note(q[note: input sort is pointless on some filesystems]);

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };

  T2->is($ret[0], 0, q[input sort run successful]);

  my @out = ($sto =~ /->.+?prove-(\d+)/g);
  my @exp = map { 100 - $_ } 1..$limit;

  T2->is(\@out, \@exp, q[input sort matches expected order])
}

T02_SORTO:
{
  local @ARGV =
  (
    qw[^prove-().+?-(\d+) prove-%02d-sort-%d --sort output -i], $testing,
    q[-m], q[0=use feature q(state); state $x = 99; $x--] #? force rev sort
  );

  my ($sto, $ste, @ret) = capture { xmrf::app::run() };

  T2->is($ret[0], 0, q[output sort run successful]);

  my @out = ($sto =~ /->.+?prove-(\d+)/g);
  my @exp = sort map { 100 - $_ } 1..$limit;

  T2->is(\@out, \@exp, q[output sort matches expected order])
}

cleanup;

T2->done_testing;
