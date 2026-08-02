#!/usr/bin/env perl

use strict;

use Test2::V1 qw[-strict -warnings -utf8];
use FindBin;
use lib qq[$FindBin::RealBin/../lib];

use xmrf::app;
T2->pass(q[xmrf::app loaded successfully]);

foreach my $c (qw[build copy execute full named recursive verbose help])
{
  T2->is(xmrf::app::cget($c), 0, qq[config "$c" is zero]);
}

foreach my $c (qw[format match])
{
  T2->is(xmrf::app::cget($c), undef, qq[config "$c" is undef]);
}

T2->is(xmrf::app::cget(q[input]), q[.], q[config "input" is "."]);
T2->is(xmrf::app::cget(q[output]), q[], q[config "output" is ""]);
T2->is(xmrf::app::cget(q[suffix]), q[(?<=.)\.([^.]+)$], q[config "suffix" is "(?<=.)\.([^.]+)$"]);

T2->is(ref(xmrf::app::cget(q[map])), q[HASH], q[config "map" is "HASH" ref]);

T2->done_testing;
