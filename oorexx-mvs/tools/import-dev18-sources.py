#!/usr/bin/env python3
"""Verify and restore a byte-identical ooRexx MVS dev18 source checkpoint.

Do not run this from a symlinked/untrusted destination or as a privileged user.
By default, verification is read-only. --extract writes only missing matching-path
files and refuses to replace changed files. This never runs any supplied script.
"""
import argparse
import hashlib
import sys
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, BadZipFile

PREFIX = "oorexx-mvs/"
MANIFEST = PREFIX + "SOURCE-SHA256SUMS"
EXPECTED_ARCHIVE = "5c15f8ac55b47d05d471d13d80f9a2e53da06ae7c5312b79e803e1d58ae9c094"


def inventory(z):
    if MANIFEST not in z.namelist():
        raise ValueError("missing SOURCE-SHA256SUMS")
    checks = {}
    for row in z.read(MANIFEST).decode("ascii").splitlines():
        sha, separator, name = row.partition("  ")
        if not separator or len(sha) != 64 or any(c not in '0123456789abcdef' for c in sha):
            raise ValueError("invalid SHA256 manifest row")
        path = PurePosixPath(name)
        if not name or path.is_absolute() or '..' in path.parts or str(path) != name:
            raise ValueError("unsafe manifest path: " + name)
        if name in checks:
            raise ValueError("duplicate manifest entry: " + name)
        checks[name] = sha
    members = [name for name in z.namelist() if not name.endswith('/')]
    if set(members) != {PREFIX + name for name in checks} | {MANIFEST}:
        raise ValueError("ZIP members do not match source manifest")
    for name, expected in checks.items():
        payload = z.read(PREFIX + name)
        if hashlib.sha256(payload).hexdigest() != expected:
            raise ValueError("content SHA256 mismatch: " + name)
    return checks


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=Path, help="oorexx-mvs-github-ready-dev18.zip")
    p.add_argument("--extract", type=Path, metavar="REPO", help="write under REPO/oorexx-mvs, never overwrite different content")
    a = p.parse_args(argv)
    try:
        actual = hashlib.sha256(a.archive.read_bytes()).hexdigest()
        if actual != EXPECTED_ARCHIVE:
            raise ValueError("archive SHA256 mismatch: expected " + EXPECTED_ARCHIVE + ", got " + actual)
        with ZipFile(a.archive) as z:
            checks = inventory(z)
            n = 0
            if a.extract:
                base = a.extract.resolve(strict=True)
                if not base.is_dir():
                    raise ValueError("repository path is not a directory")
                for name in checks:
                    target = base / PREFIX / name
                    # Deliberately prohibit symlink traversal, even when target doesn't yet exist.
                    parent = target.parent
                    while parent != base:
                        if parent.is_symlink():
                            raise ValueError("symlink parent path: " + str(parent))
                        parent = parent.parent
                    if target.is_symlink():
                        raise ValueError("symlink target: " + str(target))
                    if target.exists():
                        if hashlib.sha256(target.read_bytes()).hexdigest() != checks[name]:
                            raise ValueError("refusing to overwrite different existing file: " + str(target))
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(z.read(PREFIX + name))
                    n += 1
            print("PASS dev18 source archive: %d manifest entries, %d files extracted" % (len(checks), n))
    except (OSError, ValueError, BadZipFile) as e:
        print("FAIL:", e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
