#!/usr/bin/env python3
"""Make valid-but-unauthenticated mirrors for signature rejection tests."""
import gzip
from pathlib import Path
import shutil
import sys
import zlib

source, target = map(Path, sys.argv[1:])
shutil.copytree(source, target)
inrelease = target / 'deb/dists/stable/InRelease'
text = inrelease.read_text()
assert 'Origin: XMRF' in text
inrelease.write_text(text.replace('Origin: XMRF', 'Origin: FORGED', 1))
repomd = target / 'rpm/repodata/repomd.xml'
repomd.write_bytes(repomd.read_bytes() + b'\n<!-- altered after signing -->\n')
for index in (target / 'apk').glob('*/APKINDEX.tar.gz'):
    data = index.read_bytes()
    stream = zlib.decompressobj(31)
    signature = stream.decompress(data)
    assert b'.SIGN.RSA256.' in signature
    unsigned = stream.unused_data
    assert b'APKINDEX' in gzip.decompress(unsigned)
    index.write_bytes(unsigned)
for signature in (target / 'arch/any').glob('xmrf.*.sig'):
    signature.unlink()
print('Created mirrors with forged APT/RPM metadata and unsigned APK/Arch indexes.')
