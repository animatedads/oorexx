#!/usr/bin/env python3
"""Resolve the separately supplied, repaired RX2CPP typed-library host.

Writes the validated include-root directory to stdout. ZIP archives are staged
in the caller's build directory, not installed globally. Missing dependencies
are errors, never simulated or treated as a test pass.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path, PurePosixPath
import stat
import sys
import zipfile

HEADER = "rx2cpp_extlib.hpp"


def fail(message: str) -> None:
    raise ValueError(message)


def root_from_dir(path: Path) -> Path:
    path = path.expanduser().resolve(strict=True)
    if not path.is_dir():
        fail(f"not a directory: {path}")
    # An explicit source may be either the package root or a wrapper directory
    # left by ZIP extraction. Avoid arbitrary fallback to system headers.
    matches = sorted(path.rglob(HEADER))
    matches = [p for p in matches if p.is_file() and p.parent.name == "include"]
    if len(matches) != 1:
        fail(f"expected exactly one include/{HEADER} beneath {path}; found {len(matches)}")
    return matches[0].parent.parent


def root_from_archive(archive: Path, staging: Path) -> Path:
    archive = archive.expanduser().resolve(strict=True)
    if not archive.is_file() or not zipfile.is_zipfile(archive):
        fail(f"not a readable ZIP package: {archive}")
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if len(infos) > 10000:
            fail("ZIP contains too many entries")
        matches = []
        total = 0
        for info in infos:
            name = info.filename
            p = PurePosixPath(name)
            if not name or name.startswith("/") or "\\" in name or ".." in p.parts:
                fail(f"unsafe ZIP entry: {name!r}")
            if p.parts and ":" in p.parts[0]:
                fail(f"unsafe ZIP entry: {name!r}")
            mode = info.external_attr >> 16
            if stat.S_IFMT(mode) == stat.S_IFLNK:
                fail(f"ZIP symlinks are not permitted: {name!r}")
            total += info.file_size
            if total > 256 * 1024 * 1024:
                fail("ZIP uncompressed content exceeds 256 MiB limit")
            if len(p.parts) >= 2 and p.parts[-2:] == ("include", HEADER):
                matches.append(info.filename)
        if len(matches) != 1:
            fail(f"ZIP must contain exactly one include/{HEADER}; found {len(matches)}")
        # Stage under a caller-owned build directory. Never write to the repo.
        staging.mkdir(parents=True, exist_ok=True)
        zf.extractall(staging)
    return root_from_dir(staging)


def resolve(repo: Path, staging: Path) -> Path:
    root = os.environ.get("RX2CPP_EXTLIB_ROOT", "").strip()
    archive = os.environ.get("RX2CPP_EXTLIB_ARCHIVE", "").strip()
    if root:
        path = Path(root)
        if not path.exists():
            fail(f"RX2CPP_EXTLIB_ROOT does not exist: {path}")
        return root_from_archive(path, staging) if path.is_file() else root_from_dir(path)
    if archive:
        return root_from_archive(Path(archive), staging)
    # Intentionally a constrained set of conventional project-local candidates.
    # No machine-wide searches, network fetches, or guessed package creation.
    parents = (repo, repo.parent)
    directories = ("rx2cpp_extlib_v0.1b", "rx2cpp_extlib_v0.1", "rx2cpp_extlib", "external/extlib")
    archives = ("rx2cpp_extlib_v0.1(1).zip", "rx2cpp_extlib_v0.1b.zip", "rx2cpp_extlib_v0.1.zip")
    candidates = [(base / name) for base in parents for name in (*directories, *archives)]
    present = [p for p in candidates if p.exists()]
    if len(present) > 1:
        fail("ambiguous external library candidates: " + ", ".join(map(str, present)) +
             "; select one with RX2CPP_EXTLIB_ROOT")
    if present:
        p = present[0]
        return root_from_archive(p, staging) if p.is_file() else root_from_dir(p)
    fail("MISSING_DEPENDENCY: repaired RX2CPP external typed-library host unavailable. "
         "Provide the actual rx2cpp_extlib_v0.1b package and set either "
         "RX2CPP_EXTLIB_ROOT=/absolute/unpacked/package/root or "
         "RX2CPP_EXTLIB_ARCHIVE=/absolute/rx2cpp_extlib_v0.1(1).zip. "
         "The test has NOT run.")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo-root", required=True, type=Path)
    ap.add_argument("--staging", required=True, type=Path)
    args = ap.parse_args()
    try:
        found = resolve(args.repo_root.resolve(), args.staging.resolve())
    except (ValueError, FileNotFoundError, zipfile.BadZipFile, OSError) as exc:
        print(f"rx2cpp-extlib: {exc}", file=sys.stderr)
        return 78
    print(found)
    return 0


if __name__ == "__main__":
    sys.exit(main())
