#!/usr/bin/env perl
use v5.28;
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use IO::Compress::Gzip qw(gzip $GzipError);

require "$FindBin::Bin/../repository-fixtures.pl";

sub compressed {
    my ($data) = @_;
    gzip \$data => \my $result or die $GzipError;
    return $result;
}

sub failure (&) {
    my ($code) = @_;
    local $@;
    eval { $code->(); 1 } and return '';
    return $@;
}

my $signature = compressed('.SIGN.RSA256.xmrf-alpine.rsa.pub' . ("\0" x 2048));
my $index = compressed("APKINDEX\0P:xmrf\nV:1.3.3-r1\n");
is XMRF::RepositoryFixtures::unsigned_apk_index($signature . $index), $index,
    'only the signature gzip member is removed; compressed index bytes are unchanged';
like failure { XMRF::RepositoryFixtures::unsigned_apk_index(compressed('not a signature') . $index) },
    qr/Expected an RSA256/, 'an already unsigned index cannot masquerade as a signed fixture';
like failure { XMRF::RepositoryFixtures::unsigned_apk_index($signature . compressed('not an index')) },
    qr/Expected APKINDEX/, 'the retained member must contain the package index';
like failure { XMRF::RepositoryFixtures::unsigned_apk_index($signature . 'broken gzip') },
    qr/gzip member|Expected APKINDEX/, 'invalid trailing content is rejected';

my $tmp = tempdir('xmrf-fixture-tests-XXXXXX', TMPDIR => 1, CLEANUP => 1);
my $source = "$tmp/source with spaces";
my $target = "$tmp/tampered mirror";
make_path("$source/deb/dists/stable", "$source/rpm/repodata", "$source/arch/any",
    "$source/apk/noarch", "$source/apk/x86_64");
XMRF::RepositoryFixtures::write_file("$source/deb/dists/stable/InRelease", "Origin: XMRF\n");
XMRF::RepositoryFixtures::write_file("$source/rpm/repodata/repomd.xml", '<repomd/>');
for my $arch (qw(noarch x86_64)) {
    XMRF::RepositoryFixtures::write_file("$source/apk/$arch/APKINDEX.tar.gz", $signature . $index);
}
for my $name (qw(xmrf.db.sig xmrf.db.tar.gz.sig xmrf.files.sig xmrf.files.tar.gz.sig xmrf-1.3.3-1-any.pkg.tar.zst.sig)) {
    XMRF::RepositoryFixtures::write_file("$source/arch/any/$name", 'signature');
}
XMRF::RepositoryFixtures::main($source, $target);
is XMRF::RepositoryFixtures::read_file("$target/deb/dists/stable/InRelease"), "Origin: FORGED\n",
    'APT signed content changes';
like XMRF::RepositoryFixtures::read_file("$target/rpm/repodata/repomd.xml"),
    qr/altered after signing/, 'RPM XML remains intact with an added comment';
for my $arch (qw(noarch x86_64)) {
    is XMRF::RepositoryFixtures::read_file("$target/apk/$arch/APKINDEX.tar.gz"), $index,
        "$arch index retains exactly its original compressed payload";
    is XMRF::RepositoryFixtures::read_file("$source/apk/$arch/APKINDEX.tar.gz"), $signature . $index,
        "$arch original mirror is unchanged";
}
ok !-e "$target/arch/any/xmrf.db.sig", 'database signature is removed';
ok !-e "$target/arch/any/xmrf.files.tar.gz.sig", 'files database signature is removed';
ok -f "$target/arch/any/xmrf-1.3.3-1-any.pkg.tar.zst.sig", 'package signature is preserved';
like failure { XMRF::RepositoryFixtures::main($source, $target) },
    qr/target already exists/, 'an existing destination is not modified';

done_testing;
