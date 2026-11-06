#!/usr/bin/env perl
use v5.28;
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Digest::SHA qw(sha256_hex);
use JSON::PP;

require "$FindBin::Bin/../repository-assets.pl";

sub write_file {
    my ($path, $data) = @_;
    open my $file, '>:raw', $path or die "Write $path: $!";
    print {$file} $data or die "Write $path: $!";
    close $file or die "Close $path: $!";
}

sub failure (&) {
    my ($code) = @_;
    local $@;
    eval { $code->(); 1 } and return '';
    return $@;
}

subtest 'stable retention uses publication order' => sub {
    my @releases = (
        {tag_name => 'old', published_at => '2025-01-01'},
        {tag_name => 'preview', published_at => '2026-03-01', prerelease => 1},
        {tag_name => 'draft', published_at => '2026-03-02', draft => 1},
        {tag_name => 'new', published_at => '2026-02-01'},
    );
    is_deeply [map { $_->{tag_name} } @{XMRF::RepositoryAssets::select_releases(\@releases, 1)}],
        ['new'], 'drafts and prereleases do not displace stable releases';
};

subtest 'invalid retention is rejected' => sub {
    for my $limit ('0', '-1', '101', '1.5', 'all', '01', "1\n2") {
        like failure { XMRF::RepositoryAssets::select_releases([{}], $limit) },
            qr/REPO_SIZE must be/, "invalid limit: $limit";
    }
    is scalar(@{XMRF::RepositoryAssets::select_releases([{}], 100)}), 1,
        'upper boundary is accepted without inventing releases';
};

subtest 'empty stable history is rejected' => sub {
    like failure { XMRF::RepositoryAssets::select_releases([{prerelease => 1}], 5) },
        qr/No published stable/, 'no empty repository is produced';
};

subtest 'native APK filename' => sub {
    is_deeply XMRF::RepositoryAssets::classify('xmrf_1.3.3-r1_noarch.apk'),
        ['apk', 'apk/noarch/xmrf-1.3.3-r1.apk'], 'rename the asset for APK clients';
};

subtest 'only expected architecture independent assets' => sub {
    my %expected = (
        'xmrf_1.3.3-1_all.deb' => 'deb',
        'xmrf-1.3.3-1.noarch.rpm' => 'rpm',
        'xmrf-1.3.3-1-any.pkg.tar.zst' => 'arch',
    );
    for my $name (sort keys %expected) {
        is XMRF::RepositoryAssets::classify($name)->[0], $expected{$name}, $name;
    }
    for my $name ('../xmrf_1.3.3_all.deb', 'xmrf.exe', 'xmrf_1.3.3_amd64.deb',
        'other-1.3.3-1-any.pkg.tar.zst', 'xmrf_1.3.3_all.deb/evil') {
        ok !defined(XMRF::RepositoryAssets::classify($name)), "ignore $name";
    }
};

subtest 'GitHub digest is checked before signing' => sub {
    my $tmp = tempdir(CLEANUP => 1);
    my $file = "$tmp/package";
    write_file($file, 'original');
    my $digest = 'sha256:' . sha256_hex('original');
    ok XMRF::RepositoryAssets::verify_digest($file, $digest), 'original bytes match';
    write_file($file, 'altered');
    like failure { XMRF::RepositoryAssets::verify_digest($file, $digest) },
        qr/checksum mismatch/, 'altered bytes are rejected';
    like failure { XMRF::RepositoryAssets::verify_digest($file, 'md5:1234') },
        qr/Unsupported asset digest/, 'unknown algorithms are rejected';
    ok XMRF::RepositoryAssets::verify_digest($file, undef), 'legacy assets are supported';
};

# Exercise the real list-form subprocess pipes with a fake gh executable,
# including binary asset bytes, rather than mocking Perl's file/pipe operations.
my $tmp = tempdir('xmrf-repository-tests-XXXXXX', TMPDIR => 1, CLEANUP => 1);
make_path("$tmp/bin");
my $gh = <<'GH';
use strict;
use warnings;
use JSON::PP;
open my $file, '<:raw', $ENV{XMRF_TEST_GH_DATA} or die $!;
local $/;
my $data = JSON::PP->new->utf8->decode(<$file>);
binmode STDOUT;
if ($ARGV[1] =~ m{/releases\?}) {
    print JSON::PP->new->utf8->encode([$data->{releases}]);
} elsif ($ARGV[1] =~ m{/releases/assets/([0-9]+)\z}) {
    my $id = $1;
    exit 23 if defined($ENV{XMRF_TEST_GH_FAIL}) && $id eq $ENV{XMRF_TEST_GH_FAIL};
    print $data->{payloads}{$id};
} else {
    die "Unexpected gh arguments: @ARGV";
}
GH
write_file("$tmp/bin/gh", "#!$^X\n$gh");
chmod 0755, "$tmp/bin/gh" or die "chmod gh: $!";
local $ENV{PATH} = "$tmp/bin:$ENV{PATH}";
local $ENV{GITHUB_REPOSITORY} = 'owner/repo';
local $ENV{REPO_SIZE} = '5';
local $ENV{XMRF_TEST_GH_DATA} = "$tmp/gh.json";
my $json = JSON::PP->new->utf8;

subtest 'newest release must have all formats' => sub {
    write_file("$tmp/gh.json", $json->encode({releases => [
        {tag_name => 'v1.0.0', assets => [{name => 'xmrf_1.0.0_all.deb'}]},
    ]}));
    like failure { XMRF::RepositoryAssets::main("$tmp/missing") },
        qr/publish a four-format release first/, 'incomplete latest release fails';
    ok !-e "$tmp/missing/releases.json", 'no successful manifest is written';
};

my @names = ('xmrf_1.3.3-1_all.deb', 'xmrf-1.3.3-1.noarch.rpm',
    'xmrf_1.3.3-r1_noarch.apk', 'xmrf-1.3.3-1-any.pkg.tar.zst');
my $binary = "package\0\xff\n" x 9000; # Span more than one download read buffer.
my $new = {tag_name => 'v1.3.3', published_at => '2026-02-01', assets => [
    map { {id => $_ + 1, name => $names[$_], digest => 'sha256:' . sha256_hex($binary)} } 0 .. $#names,
]};
my $old = {tag_name => 'v1.3.2', published_at => '2026-01-01', assets => [
    {id => 5, name => 'xmrf_1.3.2_all.deb'},
    {id => 6, name => 'xmrf-1.3.2-1.noarch.rpm'},
]};
my $fixture = {releases => [$old, $new], payloads => {map { $_ => $binary } 1 .. 6}};

subtest 'older two-format release is retained and APK renamed' => sub {
    write_file("$tmp/gh.json", $json->encode($fixture));
    XMRF::RepositoryAssets::main("$tmp/output with spaces");
    ok -f "$tmp/output with spaces/apk/noarch/xmrf-1.3.3-r1.apk", 'canonical APK name';
    ok -f "$tmp/output with spaces/deb/pool/main/xmrf_1.3.2_all.deb", 'legacy DEB retained';
    open my $manifest, '<:raw', "$tmp/output with spaces/releases.json" or die $!;
    my $data = do { local $/; $json->decode(<$manifest>) };
    close $manifest;
    is_deeply [map { $_->{tag} } @$data], ['v1.3.3', 'v1.3.2'], 'manifest order';
    is scalar(@{$data->[0]{packages}}) + scalar(@{$data->[1]{packages}}), 6, 'six assets downloaded';
};

subtest 'failed downloads and invalid retention cannot produce a successful site' => sub {
    local $ENV{XMRF_TEST_GH_FAIL} = 1;
    like failure { XMRF::RepositoryAssets::main("$tmp/failed-download") },
        qr/Asset download failed/, 'subprocess failure is propagated';
    ok !-e "$tmp/failed-download/releases.json", 'no successful manifest after failure';
    local $ENV{REPO_SIZE} = '0';
    like failure { XMRF::RepositoryAssets::main("$tmp/invalid-limit") },
        qr/REPO_SIZE must be/, 'zero is rejected rather than treated as the default';
};

done_testing;
