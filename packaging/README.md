# Release packaging

`nfpm.yaml` defines one architecture-independent payload for DEB (APT), RPM,
Alpine APK, and Arch Linux packages. nFPM translates `arch: all` to `all`,
`noarch`, `noarch`, and `any`, respectively. Perl 5.28 or newer is required;
the launcher retains its version guard.

## Build locally

Install Perl (including `pod2man`), gzip, Git, Go 1.27.3, and nFPM:

```sh
go install github.com/goreleaser/nfpm/v2/cmd/nfpm@v2.48.0
export PATH="$(go env GOPATH)/bin:$PATH"
bash .github/scripts/package.sh v1.3.3
```

Packages are written to `dist/`. The source files are never rewritten.
Existing `v1.3.3-alpha-1` and `v1.3.3-beta-1` tags are accepted; the prerelease
suffix becomes `alpha1` or `beta1` for compatibility with Alpine's version
grammar. nFPM supplies the separator appropriate to each format. Each package
contains the launcher, application module, compressed manpage, copyright,
and full license.

An explicit epoch of zero works around nFPM 2.48.0 omitting prereleases from
Arch's `.PKGINFO` when no epoch is set. Zero has the same ordering as an absent
epoch, and ensures the installed version matches the package filename.

## Tests and releases

The release workflow runs on matching pull requests, manual dispatches, and
`v*` tag pushes. Only tag pushes can create a draft release, after Windows and
every Linux package test pass. Pull requests and manual runs build packages
using the module version; they never publish a release.

Linux tests download artifacts on the Ubuntu host, then use `docker run` to
install and test them in Debian 12/13, Ubuntu 22.04/24.04/26.04, Fedora 43/44,
Rocky 9/10, Alpine 3.22/3.23/3.24, and rolling Arch Linux. This keeps JavaScript
actions outside Alpine's musl environment. End-of-life Ubuntu 20.04 and Fedora
38/40/42 have been retired from the matrix.

The source suite runs on Ubuntu and Strawberry Perl. Each Linux package test
checks runtime dependency resolution, installed documentation, CLI help and
version output, a dry run, an actual rename with content verification, and
uninstallation. These are package integration tests; the full Perl unit suite
does not run inside each Linux container. `--version` currently exits 1, and
the smoke tests explicitly check that existing behavior.

Windows remains a portable PAR-packed `xmrf.exe`. `PAR::Packer` is installed
explicitly. POD and the patched module are staged under `dist/`; packing does
not edit `lib/`. A separate runner tests the EXE without Perl on `PATH`.
MSIX is unnecessary for portable CLI distribution; revisit it if Store
distribution or managed installation becomes a requirement.

## Supply chain and signing

All top-level action references in the release and repository-publishing
workflows use verified upstream commit SHAs with version comments. Weekly
Dependabot pull requests keep those action pins reviewable. nFPM and Go use
exact versions; Go's checksum database verifies nFPM and its module downloads.
Dependabot's GitHub Actions updater does not update these inline tool versions.

Build and test jobs have read-only repository permissions and do not persist
checkout credentials. Only the draft-release job has `contents: write`.
Drafts include `SHA256SUMS` for every package and the EXE; checksums detect
corruption but are not signatures or provenance attestations.

APK and Arch assets are downloadable packages, not signed package repositories.
The isolated Alpine test uses `--allow-untrusted` for the local unsigned APK;
do not treat that as an installation policy for a public repository. Existing
APT/RPM repository publishing and signing remain in `publish.yml`. This change
does not provision Alpine or Arch repository keys or indexes.

Action SHA pins do not freeze dependencies fetched by actions or installers.
Container tags, distro mirrors, Chocolatey/Strawberry Perl, and CPAN module
downloads still follow their upstreams. Pages artifacts are archived directly
and uploaded with the pinned artifact action, avoiding a nested action reference.
For stronger reproducibility, separately lock container digests and the Windows
toolchain/CPAN distributions, and review updates before merging them.
