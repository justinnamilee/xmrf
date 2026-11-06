#!/usr/bin/env perl
use v5.28;
use strict;
use warnings;
use File::Path qw(make_path);

sub read_file {
    my ($path) = @_;
    open my $fh, '<', $path or die "Read $path: $!";
    local $/;
    return <$fh>;
}

sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>', $path or die "Write $path: $!";
    print {$fh} $text or die "Write $path: $!";
    close $fh or die "Close $path: $!";
}

make_path('dist/lib/xmrf', 'dist/bin');
my $entry = read_file('bin/xmrf');
write_file('dist/bin/xmrf', $entry);
$entry =~ /^__END__\r?\n(.*)\z/ms or die "No POD in bin/xmrf";
write_file('dist/xmrf.pod', $1);

# Stage a separate module so packaging never rewrites the source tree.
my $app = read_file('lib/xmrf/app.pm');
$app =~ s/use strict;/use strict; use PAR ();/ or die "No strict marker";
$app =~ s/\Q#*EXE POD*#\E/my \$pod = PAR::read_file('xmrf.pod');\n  open(my \$pfh, '<', \\\$pod) or die \$!;/
    or die "No EXE POD marker";
$app =~ s/-input => \$0/-input => \$pfh/ or die "No POD input marker";
write_file('dist/lib/xmrf/app.pm', $app);
