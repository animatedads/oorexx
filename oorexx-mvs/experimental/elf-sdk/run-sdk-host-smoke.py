#!/usr/bin/env python3
"""Fail-closed host-side Mainframe ELF SDK TSO24/TSO31 packaging qualification.

Checks the SDK's recorded native source/link outputs, not merely a nonempty
XMIT. A passing host receipt never authorizes or asserts guest execution.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

VALID_PROFILES = {
    "tso-zos24-v1": ("RXMVS24.XMI", 24, "24"),
    "tso-zos31-v1": ("RXMVS31.XMI", 31, "ANY"),
}
RECEIPT_NAME = "oorexx-mvs-host-report.json"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def descendant(path, parent):
    return path == parent or parent in path.parents


def check_file(path):
    """Never follow a symlink when verifying the declared build artifacts."""
    return path.is_file() and not path.is_symlink() and path.stat().st_size > 0


def check_receipt(output, sdk, profile, source):
    """Cross-check installed SDK v0.1.0's result.json and physical artifacts.

    No receipt is an MVS/zOS execution result. This only checks the SDK's
    *claimed host link* against its named outputs and our requested source.
    """
    xmit_name, amode, rmode = VALID_PROFILES[profile]
    target = output / profile
    receipt_file = output / "result.json"
    required = [receipt_file, target / "consumer.c", target / "consumer.elf",
                target / "consumer.obj", target / xmit_name]
    if not all(check_file(path) for path in required):
        return False, "Missing, empty or symlinked SDK result or output", {}
    try:
        receipt = json.loads(receipt_file.read_text(encoding="utf-8"))
        if receipt.get("format") != "mainframe-compiler-sdk-consumer-v1":
            raise ValueError("Wrong SDK receipt format")
        if receipt.get("sdk_manifest_sha256") != sha256(sdk / "SDK-MANIFEST.json"):
            raise ValueError("SDK manifest digest differs")
        profile_results = receipt.get("profiles", {})
        if set(profile_results) != {profile}:
            raise ValueError("SDK receipt profile set differs")
        data = profile_results[profile]
        link = data["source_native_links"]["default"]
        expected = {
            "source_sha256": sha256(source),
            "elf_sha256": sha256(target / "consumer.elf"),
            "native_deck_sha256": sha256(target / "consumer.obj"),
        }
        for key, digest in expected.items():
            if data.get(key) != digest:
                raise ValueError("SDK receipt mismatched " + key)
        if sha256(target / "consumer.c") != expected["source_sha256"]:
            raise ValueError("The copied consumer source differs")
        if link.get("xmit_sha256") != sha256(target / xmit_name):
            raise ValueError("Native XMIT digest differs")
        if link.get("member") != xmit_name.removesuffix(".XMI"):
            raise ValueError("Native member identity differs")
        if str(link.get("amode")) != str(amode) or str(link.get("rmode")).upper() != rmode:
            raise ValueError("Native AMODE/RMODE differs")
        return True, "SDK receipt hashes, identity, mode and outputs agree", {
            "sdk_receipt_sha256": sha256(receipt_file),
            "elf_sha256": expected["elf_sha256"],
            "native_deck_sha256": expected["native_deck_sha256"],
        }
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return False, "SDK host receipt invalid: " + str(exc), {}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--profile", choices=sorted(VALID_PROFILES), required=True)
    parser.add_argument("--out", type=Path, required=True, help="new absolute output directory")
    parser.add_argument("--timeout-sec", type=float, default=900,
                        help="maximum child execution seconds, default 900")
    args = parser.parse_args(argv)
    if args.timeout_sec <= 0 or args.timeout_sec > 3600:
        raise ValueError("timeout-sec must be between 0 and 3600 seconds")
    script = Path(__file__).resolve()
    source = script.with_name("z_backend_contract.c")
    sdk, output = args.sdk, args.out
    if not sdk.is_absolute() or not output.is_absolute():
        raise ValueError("sdk and out must be absolute paths")
    if not sdk.is_dir() or sdk.is_symlink():
        raise ValueError("SDK must be an existing real directory")
    sdk = sdk.resolve(strict=True)
    if output.exists() or output.is_symlink():
        raise ValueError("out must not exist; no overwrite")
    if not output.parent.is_dir() or output.parent.is_symlink():
        raise ValueError("output parent must be an existing real directory")
    output = output.resolve(strict=False)
    if (descendant(output, sdk) or descendant(sdk, output) or
            descendant(output, script.parent) or descendant(script.parent, output)):
        raise ValueError("output overlaps installed SDK or qualification sources")
    consumer = sdk / "tools" / "compiler_sdk_consume.py"
    manifest = sdk / "SDK-MANIFEST.json"
    if not all(check_file(p) for p in (consumer, manifest, source)):
        raise ValueError("missing, empty, or symlinked SDK consumer, manifest or source")
    command = [sys.executable, str(consumer), "--sdk", str(sdk),
               "--profile", args.profile, "--tso-source", str(source),
               "--member-prefix", "RXMVS", "--out", str(output)]
    timeout = False
    try:
        child = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, check=False,
                               timeout=args.timeout_sec)
        stdout, stderr, rc = child.stdout, child.stderr, child.returncode
    except subprocess.TimeoutExpired as exc:
        timeout = True
        rc = None
        stdout = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = exc.stderr.decode(errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
    target = output / args.profile
    xmit = target / VALID_PROFILES[args.profile][0]
    packaged = rc == 0
    evidence_ok, evidence_reason, link_details = (check_receipt(output, sdk, args.profile, source)
        if packaged else (False, "SDK consumer unsuccessful or timed out", {}))
    report = {
        "schema": "oorexx.mvs.elf_sdk.host_smoke/2",
        "profile": args.profile,
        "sdk_manifest_sha256": sha256(manifest),
        "source_sha256": sha256(source),
        "consumer_exit_code": rc,
        "consumer_timed_out": timeout,
        "host_packaging_verified": packaged and evidence_ok,
        "host_verification_reason": evidence_reason,
        "xmit_present": check_file(xmit),
        "xmit_sha256": sha256(xmit) if check_file(xmit) else None,
        "guest_executed": False,
        "guest_return_code": None,
        "guest_qualified": False,
        **link_details,
    }
    if output.is_dir() and not output.is_symlink():
        (output / RECEIPT_NAME).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        (output / "oorexx-mvs-sdk-stdout.txt").write_text(stdout)
        (output / "oorexx-mvs-sdk-stderr.txt").write_text(stderr)
    if not report["host_packaging_verified"]:
        print("FAIL SDK host packaging/receipt: " + evidence_reason, file=sys.stderr)
        print(json.dumps(report, indent=2, sort_keys=True))
        return 1
    print("PASS SDK host packaging and receipt; guest execution NOT_RUN")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as exc:
        print("FAIL preflight: " + str(exc), file=sys.stderr)
        sys.exit(2)
