#!/usr/bin/env python3
"""Isolated Mainframe ELF SDK TSO24/TSO31 host-side packaging probe.

The installed SDK verifies its own manifest. This harness refuses unsafe paths
and reports evidence, never claims guest RC 42 and never alters an installed SDK.

SDK docs: sdk/doc/INSTALLED-README.md at v0.1.0.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

VALID_PROFILES = {
    "tso-zos24-v1": "RXMVS24.XMI",
    "tso-zos31-v1": "RXMVS31.XMI",
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def descendant(a, b):
    return a == b or b in a.parents


def fail(message):
    raise ValueError(message)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True, help="unpacked installed SDK root")
    parser.add_argument("--profile", choices=sorted(VALID_PROFILES), required=True)
    parser.add_argument("--out", type=Path, required=True, help="new output path (must not exist)")
    args = parser.parse_args(argv)
    script = Path(__file__).resolve()
    source = script.with_name("z_backend_contract.c")
    sdk = args.sdk
    output = args.out
    if not sdk.is_absolute() or not output.is_absolute():
        fail("sdk and out must be absolute paths")
    if not sdk.is_dir() or sdk.is_symlink():
        fail("SDK must be a real directory")
    sdk = sdk.resolve()
    if output.exists() or output.is_symlink():
        fail("out must not exist; existing output will never be overwritten")
    if not output.parent.is_dir() or output.parent.is_symlink():
        fail("output parent must be a real existing directory")
    output = output.resolve(strict=False)
    if descendant(output, sdk) or descendant(sdk, output):
        fail("output overlaps the installed SDK")
    if descendant(output, script.parent) or descendant(script.parent, output):
        fail("output overlaps qualification sources")
    consumer = sdk / "tools" / "compiler_sdk_consume.py"
    manifest = sdk / "SDK-MANIFEST.json"
    if not consumer.is_file() or not manifest.is_file():
        fail("missing installed SDK consumer or manifest")
    if not source.is_file():
        fail("missing C ABI probe source")
    command = [sys.executable, str(consumer), "--sdk", str(sdk),
               "--profile", args.profile, "--tso-source", str(source),
               "--member-prefix", "RXMVS", "--out", str(output)]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    xmi = output / args.profile / VALID_PROFILES[args.profile]
    report = {
        "schema": "oorexx.mvs.elf_sdk.host_smoke/1",
        "profile": args.profile,
        "target": "zOS_TSO24" if args.profile == "tso-zos24-v1" else "zOS_TSO31",
        "sdk_manifest_sha256": sha256(manifest),
        "source_sha256": sha256(source),
        "consumer_exit_code": result.returncode,
        "xmit_present": xmi.is_file() and xmi.stat().st_size > 0,
        "xmit_sha256": sha256(xmi) if xmi.is_file() and xmi.stat().st_size > 0 else None,
        "guest_executed": False,
        "guest_return_code": None,
        "guest_qualified": False,
    }
    if output.is_dir():
        (output / "oorexx-mvs-host-report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        (output / "oorexx-mvs-sdk-stdout.txt").write_text(result.stdout)
        (output / "oorexx-mvs-sdk-stderr.txt").write_text(result.stderr)
    if result.returncode != 0 or not report["xmit_present"]:
        print("FAIL host SDK packaging (guest not attempted)", file=sys.stderr)
        print(json.dumps(report, indent=2, sort_keys=True))
        return 1
    print("PASS host SDK packaging, profile=" + args.profile + "; no guest execution")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print("FAIL preflight: " + str(exc), file=sys.stderr)
        sys.exit(2)
