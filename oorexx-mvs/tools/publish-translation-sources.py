#!/usr/bin/env python3
"""Safely publish exact ooRexx MVS dev18 translation sources from the ZIP.

Default: verification-only preview. --apply extracts missing files;
--push also commits and attempts a normal fast-forward push to origin/main.
Never overwrites changed files or stages unrelated project work.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from zipfile import ZipFile, BadZipFile

ARCHIVE_SHA256 = "2c97eb99e5c2c5a0057132d0c6832e1dcbfa2fec9655871ea9134aaccfa4655c"
PREFIX = "oorexx-mvs/"


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True, stderr=subprocess.PIPE).strip()


def blob_sha(raw):
    return hashlib.sha1(("blob %d\0" % len(raw)).encode("ascii") + raw).hexdigest()


def run(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("archive", type=Path, help="exact oorexx-mvs-translation-scripts-dev18.zip")
    ap.add_argument("repo", type=Path, help="local animatedads/oorexx checkout")
    ap.add_argument("--apply", action="store_true", help="write only missing files")
    ap.add_argument("--push", action="store_true", help="commit and fast-forward push; implies --apply")
    args = ap.parse_args(argv)
    repo = args.repo.resolve(strict=True)
    expected = json.loads((repo / PREFIX / "evidence/translation-source-blobs.json").read_text())
    if expected["schema"] != "oorexx.mvs.translation.sources/1":
        raise ValueError("unrecognized translation manifest")
    if hashlib.sha256(args.archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("source archive digest mismatch")
    if git(repo, "rev-parse", "--show-toplevel") != str(repo):
        raise ValueError("not a repository root")
    if git(repo, "branch", "--show-current") != "main":
        raise ValueError("must run on main")
    if git(repo, "status", "--porcelain"):
        raise ValueError("repository must be clean; do not cross other work")
    with ZipFile(args.archive) as z:
        names = [i.filename for i in z.infolist()]
        wanted = [PREFIX + n for n in expected["files"]]
        if len(names) != len(set(names)) or set(names) != set(wanted):
            raise ValueError("archive paths differ from versioned source manifest")
        pending = []
        for name, sha in expected["files"].items():
            if name.startswith("/") or ".." in Path(name).parts or "\\" in name:
                raise ValueError("unsafe source name: " + name)
            data = z.read(PREFIX + name)
            if blob_sha(data) != sha:
                raise ValueError("source blob mismatch: " + name)
            target = repo / PREFIX / name
            if target.is_symlink() or any(p.is_symlink() for p in target.parents if p != repo):
                raise ValueError("symlink path: " + name)
            if target.exists():
                if target.read_bytes() != data:
                    raise ValueError("refusing to overwrite different source: " + name)
            else:
                pending.append((target, data))
        print("Verified", len(wanted), "translation-source blobs; missing", len(pending))
        for target, data in pending:
            print("  +", target.relative_to(repo).as_posix(), len(data), "bytes")
        if not (args.apply or args.push):
            return 0
        for target, data in pending:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if not args.push:
            print("Extracted missing translation sources; no commit or push")
            return 0
        if not pending:
            print("All translation sources already present; nothing to commit")
            return 0
        paths = [str(t.relative_to(repo)) for t, _ in pending]
        subprocess.run(["git", "-C", str(repo), "add", "--", *paths], check=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-m", "Publish verified dev18 MVS translation sources", "--", *paths], check=True)
        subprocess.run(["git", "-C", str(repo), "push", "origin", "HEAD:main"], check=True)
        print("PASS committed and pushed translation sources")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(run())
    except (OSError, ValueError, BadZipFile, subprocess.CalledProcessError, KeyError) as exc:
        print("FAIL:", exc, file=sys.stderr)
        sys.exit(1)
