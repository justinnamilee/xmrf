#!/usr/bin/env perl

use strict;

use Test2::V1 qw[-strict -warnings -utf8];
use FindBin;
use lib qq[$FindBin::RealBin/../lib];

use xmrf::app;
T2->pass(q[xmrf::app loaded successfully]);

my $testing = qq[$FindBin::RealBin/../testing];

mkdir $testing || T2->bail_out($!)
  unless (-d $testing);

ARGV:
{
  local @ARGV = qw[];
  # TODO: here we can call xmrf::app::run()
}

T2->done_testing;
