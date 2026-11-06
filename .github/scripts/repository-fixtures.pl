#!/usr/bin/env perl
package XMRF::RepositoryFixtures;
use v5.28;
use strict;
use warnings;
use Compress::Raw::Zlib qw(MAX_WBITS Z_OK Z_STREAM_END);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

sub read_file {
    my ($path) = @_;
    open my $file, '<:raw', $path or die "Read $path: $!\n";
    local $/;
    my $data = <$file>;
    close $file or die "Close $path: $!\n";
    return $data // '';
}

sub write_file {
    my ($path, $data) = @_;
    open my $file, '>:raw', $path or die "Write $path: $!\n";
    print {$file} $data or die "Write $path: $!\n";
    close $file or die "Close $path: $!\n";
}

sub unsigned_apk_index {
    my ($data) = @_;
    # Consume exactly the signature's gzip member, retaining the compressed
    # APKINDEX member byte-for-byte. The negative control remains a valid index.
    my ($inflate, $status) = Compress::Raw::Zlib::Inflate->new(
        -WindowBits => MAX_WBITS() + 16, -ConsumeInput => 1,
    );
    die "Initialize gzip reader: $status\n" unless $status == Z_OK;
    $status = $inflate->inflate($data, my $signature);
    die "Invalid signature gzip member: $status\n" unless $status == Z_STREAM_END;
    die "Expected an RSA256 index signature\n" unless $signature =~ /\.SIGN\.RSA256\./;
    gunzip \$data => \my $index, MultiStream => 0, Transparent => 0
        or die "Read APKINDEX gzip member: $GunzipError\n";
    die "Expected APKINDEX content\n" unless $index =~ /APKINDEX/;
    return $data;
}

sub main {
    my ($source, $target) = @_;
    die "Usage: repository-fixtures.pl SOURCE TARGET\n"
        unless defined($source) && defined($target);
    die "Mirror source is not a directory: $source\n" unless -d $source;
    die "Mirror target already exists: $target\n" if -e $target;
    # GNU cp is already present on the Ubuntu test host; preserve complete
    # directory contents and dereference any links, as the previous helper did.
    system('cp', '-aL', '--', $source, $target) == 0 or die "Copy mirror failed\n";
    my $inrelease = "$target/deb/dists/stable/InRelease";
    my $text = read_file($inrelease);
    $text =~ s/Origin: XMRF/Origin: FORGED/ or die "Expected XMRF Origin\n";
    write_file($inrelease, $text);
    my $repomd = "$target/rpm/repodata/repomd.xml";
    write_file($repomd, read_file($repomd) . "\n<!-- altered after signing -->\n");
    opendir my $apk, "$target/apk" or die "Read APK mirror: $!\n";
    my @arches = grep { $_ ne '.' && $_ ne '..' } readdir $apk;
    closedir $apk or die "Close APK mirror: $!\n";
    for my $arch (@arches) {
        my $index = "$target/apk/$arch/APKINDEX.tar.gz";
        next unless -f $index;
        write_file($index, unsigned_apk_index(read_file($index)));
    }
    opendir my $arch, "$target/arch/any" or die "Read Arch mirror: $!\n";
    my @signatures = grep { /\Axmrf\..*\.sig\z/ } readdir $arch;
    closedir $arch or die "Close Arch mirror: $!\n";
    unlink "$target/arch/any/$_" or die "Remove $_: $!\n" for @signatures;
    print "Created mirrors with forged APT/RPM metadata and unsigned APK/Arch indexes.\n";
}

main(@ARGV) unless caller;
1;
