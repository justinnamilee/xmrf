#!/usr/bin/env perl
package XMRF::RepositoryAssets;
use v5.28;
use strict;
use warnings;
use Digest::SHA;
use Fcntl qw(O_WRONLY O_CREAT O_EXCL);
use File::Basename qw(dirname basename);
use File::Path qw(make_path);
use JSON::PP;

sub select_releases {
    my ($releases, $limit) = @_;
    die "REPO_SIZE must be an integer from 1 to 100\n"
        unless defined($limit) && $limit =~ /\A(?:[1-9][0-9]?|100)\z/;
    my @stable = sort {
        ($b->{published_at} // '') cmp ($a->{published_at} // '')
    } grep { !$_->{draft} && !$_->{prerelease} } @$releases;
    die "No published stable releases found\n" unless @stable;
    splice @stable, $limit if @stable > $limit;
    return \@stable;
}

sub classify {
    my ($name) = @_;
    return ['deb', "deb/pool/main/$name"]
        if $name =~ /\Axmrf_[0-9][A-Za-z0-9.+~_-]*_all\.deb\z/;
    return ['rpm', "rpm/$name"]
        if $name =~ /\Axmrf-[0-9][A-Za-z0-9.+~_-]*\.noarch\.rpm\z/;
    # APK clients request <name>-<version>.apk, not nFPM's asset filename.
    return ['apk', "apk/noarch/xmrf-$1.apk"]
        if $name =~ /\Axmrf_([0-9][A-Za-z0-9.+~_-]*)_noarch\.apk\z/;
    return ['arch', "arch/any/$name"]
        if $name =~ /\Axmrf-[0-9][A-Za-z0-9.+~_-]*-any\.pkg\.tar\.zst\z/;
    return;
}

sub verify_digest {
    my ($path, $digest) = @_;
    return 1 unless defined $digest; # Older GitHub assets may lack a digest.
    die 'Unsupported asset digest for ' . basename($path) . "\n"
        unless $digest =~ /\Asha256:([a-fA-F0-9]{64})\z/;
    my $expected = lc $1;
    open my $file, '<:raw', $path or die "Read $path: $!\n";
    my $actual = Digest::SHA->new(256)->addfile($file)->hexdigest;
    close $file or die "Close $path: $!\n";
    die 'Asset checksum mismatch: ' . basename($path) . "\n"
        unless $actual eq $expected;
    return 1;
}

sub gh_capture {
    # List-form pipes never interpolate release names or filenames into a shell.
    open my $pipe, '-|', 'gh', @_ or die "Start gh: $!\n";
    binmode $pipe;
    local $/;
    my $data = <$pipe>;
    close $pipe or die "gh failed (status $?)\n";
    return $data // '';
}

sub download_asset {
    my ($repo, $asset, $path) = @_;
    my $id = $asset->{id};
    die "Invalid GitHub asset ID\n" unless defined($id) && $id =~ /\A[0-9]+\z/;
    make_path(dirname($path));
    sysopen my $file, $path, O_WRONLY | O_CREAT | O_EXCL
        or die "Create $path: $!\n";
    binmode $file;
    open my $pipe, '-|', 'gh', 'api', "repos/$repo/releases/assets/$id",
        '--header', 'Accept: application/octet-stream'
        or die "Start gh: $!\n";
    binmode $pipe;
    while (1) {
        my $length = read($pipe, my $buffer, 65536);
        die "Read asset $id: $!\n" unless defined $length;
        last unless $length;
        print {$file} $buffer or die "Write $path: $!\n";
    }
    close $pipe or die "Asset download failed (status $?)\n";
    close $file or die "Close $path: $!\n";
    verify_digest($path, $asset->{digest});
}

sub main {
    my ($output) = @_;
    $output //= 'site';
    my $repo = $ENV{GITHUB_REPOSITORY} // die "GITHUB_REPOSITORY is required\n";
    die "Output already exists: $output; use a fresh directory\n" if -e $output;
    my $json = JSON::PP->new->utf8;
    my $pages = $json->decode(gh_capture(
        'api', "repos/$repo/releases?per_page=100", '--paginate', '--slurp',
    ));
    my @releases = map { @$_ } @$pages;
    my $limit = defined($ENV{REPO_SIZE}) && length($ENV{REPO_SIZE})
        ? $ENV{REPO_SIZE} : '5';
    my $selected = select_releases(\@releases, $limit);
    my @manifest;
    for my $index (0 .. $#$selected) {
        my $release = $selected->[$index];
        my @assets = map { [$_, classify($_->{name})] } @{$release->{assets}};
        my %available = map { $_->[1][0] => 1 } grep { defined $_->[1] } @assets;
        my @missing = grep { !$available{$_} } qw(apk arch deb rpm);
        die "Newest stable release $release->{tag_name} is missing "
            . join(', ', @missing) . "; publish a four-format release first\n"
            if $index == 0 && @missing;
        my @files;
        for my $entry (@assets) {
            my ($asset, $info) = @$entry;
            next unless defined $info;
            my $relative = $info->[1];
            print "Downloading $release->{tag_name}: $asset->{name}\n";
            download_asset($repo, $asset, "$output/$relative");
            push @files, $relative;
        }
        push @manifest, {tag => $release->{tag_name}, packages => \@files};
    }
    open my $manifest, '>:raw', "$output/releases.json" or die "Write manifest: $!\n";
    print {$manifest} $json->canonical->pretty->encode(\@manifest)
        or die "Write manifest: $!\n";
    close $manifest or die "Close manifest: $!\n";
}

unless (caller) {
    eval { main(@ARGV); 1 } or do {
        print STDERR "Repository download failed: $@";
        exit 1;
    };
}
1;
