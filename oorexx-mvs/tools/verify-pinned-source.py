#!/usr/bin/env python3
"""Fail-closed check of GitHub source revision and all nine residual blobs.

Usage: verify-pinned-source.py /path/to/ooRexx-checkout
Never silently checks out branches or modifies the source tree.
"""
import json
import subprocess
import sys
from pathlib import Path


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args], text=True, stderr=subprocess.PIPE
    ).strip()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify-pinned-source.py /path/to/ooRexx-checkout", file=sys.stderr)
        return 2
    source = Path(sys.argv[1]).resolve()
    manifest = json.loads((Path(__file__).resolve().parent.parent / "evidence" / "github-pinned-residual.json").read_text())
    try:
        if git(source, "rev-parse", "HEAD") != manifest["commit"]:
            print("FAIL source HEAD is not the pinned ooRexx commit", file=sys.stderr)
            return 1
        for spec in manifest["files"]:
            actual = git(source, "rev-parse", "HEAD:" + spec["path"])
            if actual != spec["git_blob_sha"]:
                print("FAIL blob mismatch " + spec["path"], file=sys.stderr)
                return 1
    except (OSError, subprocess.CalledProcessError) as exc:
        print("FAIL source unavailable or not a checkout: " + str(exc), file=sys.stderr)
        return 1
    print("PASS pinned source commit and nine residual Git blobs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
