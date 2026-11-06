#!/usr/bin/env python3
"""Download stable release assets, retaining compatibility with older DEB/RPM releases."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

FORMATS = {
    "deb": (re.compile(r"xmrf_[0-9][A-Za-z0-9.+~_-]*_all\.deb"), "deb/pool/main"),
    "rpm": (re.compile(r"xmrf-[0-9][A-Za-z0-9.+~_-]*\.noarch\.rpm"), "rpm"),
    "apk": (re.compile(r"xmrf_([0-9][A-Za-z0-9.+~_-]*)_noarch\.apk"), "apk/noarch"),
    "arch": (re.compile(r"xmrf-[0-9][A-Za-z0-9.+~_-]*-any\.pkg\.tar\.zst"), "arch/any"),
}


def select_releases(releases, limit):
    if not re.fullmatch(r"[1-9][0-9]?|100", str(limit)):
        raise ValueError("REPO_SIZE must be an integer from 1 to 100")
    stable = [r for r in releases if not r.get("draft") and not r.get("prerelease")]
    stable.sort(key=lambda r: r.get("published_at") or "", reverse=True)
    if not stable:
        raise ValueError("No published stable releases found")
    return stable[:int(limit)]


def classify(name):
    for kind, (pattern, directory) in FORMATS.items():
        match = pattern.fullmatch(name)
        if match:
            # APK clients request <name>-<version>.apk, not nFPM's asset filename.
            target = f"xmrf-{match[1]}.apk" if kind == "apk" else name
            return kind, Path(directory) / target
    return None


def verify_digest(path, digest):
    if digest is None:
        return  # Older GitHub assets may not have a digest.
    if not re.fullmatch(r"sha256:[a-fA-F0-9]{64}", digest):
        raise ValueError(f"Unsupported asset digest for {path.name}")
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest[7:].lower():
        raise ValueError(f"Asset checksum mismatch: {path.name}")


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "site")
    if output.exists():
        raise ValueError(f"Output already exists: {output}; use a fresh directory")
    data = json.loads(subprocess.check_output([
        "gh", "api", f"repos/{repo}/releases?per_page=100", "--paginate", "--slurp",
    ]))
    releases = select_releases([r for page in data for r in page], os.getenv("REPO_SIZE") or "5")
    manifest = []
    for index, release in enumerate(releases):
        assets = [(a, classify(a["name"])) for a in release["assets"]]
        available = {info[0] for _, info in assets if info}
        if index == 0 and available != set(FORMATS):
            missing = ", ".join(sorted(set(FORMATS) - available))
            raise ValueError(f"Newest stable release {release['tag_name']} is missing {missing}; publish a four-format release first")
        files = []
        for asset, info in assets:
            if not info:
                continue
            _, relative = info
            path = output / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            print(f"Downloading {release['tag_name']}: {asset['name']}", flush=True)
            with path.open("xb") as target:
                subprocess.run([
                    "gh", "api", f"repos/{repo}/releases/assets/{int(asset['id'])}",
                    "--header", "Accept: application/octet-stream",
                ], stdout=target, check=True)
            verify_digest(path, asset.get("digest"))
            files.append(relative.as_posix())
        manifest.append({"tag": release["tag_name"], "packages": files})
    (output / "releases.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Repository download failed: {exc}")
