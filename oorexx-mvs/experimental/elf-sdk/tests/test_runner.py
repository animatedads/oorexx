#!/usr/bin/env python3
"""Host-only contract tests with synthetic SDK consumer; NOT toolchain tests."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / "run-sdk-host-smoke.py"

class SdkSmokeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rx-sdk-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sdk = self.root / "installed-sdk"
        (self.sdk / "tools").mkdir(parents=True)
        (self.sdk / "SDK-MANIFEST.json").write_text('{"synthetic":"not a real SDK"}\n')
        consumer = self.sdk / "tools" / "compiler_sdk_consume.py"
        consumer.write_text('''import argparse, pathlib, sys
p=argparse.ArgumentParser()
for flag in ('sdk','profile','tso-source','member-prefix','out'):
    p.add_argument('--'+flag, required=True)
a=p.parse_args()
assert pathlib.Path(a.tso_source).is_file()
if pathlib.Path(a.sdk,'fail.txt').exists():sys.exit(31)
out=pathlib.Path(a.out)
(out / a.profile).mkdir(parents=True)
if not pathlib.Path(a.sdk,'omit.txt').exists():
    suffix='24' if a.profile=='tso-zos24-v1' else '31'
    (out / a.profile / (a.member_prefix+suffix+'.XMI')).write_bytes(b'SYNTHETIC-NOT-REAL-XMIT')
''')
        self.out = self.root / "new-output"

    def run_cli(self, profile="tso-zos31-v1", **kwargs):
        arguments = {"sdk":str(self.sdk), "profile":profile, "out":str(self.out)}
        arguments.update(kwargs)
        argv = [sys.executable, str(SCRIPT)]
        for k,v in arguments.items():argv.extend(("--"+k,str(v)))
        return subprocess.run(argv, capture_output=True, text=True, timeout=15)

    def test_tso31_contract(self):
        p=self.run_cli()
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        report=json.loads((self.out/'oorexx-mvs-host-report.json').read_text())
        self.assertTrue(report['xmit_present'])
        self.assertIsNotNone(report['xmit_sha256'])
        self.assertFalse(report['guest_qualified'])
        self.assertFalse(report['guest_executed'])
        self.assertIsNone(report['guest_return_code'])

    def test_tso24_contract(self):
        p=self.run_cli(profile='tso-zos24-v1')
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        self.assertTrue((self.out/'tso-zos24-v1'/'RXMVS24.XMI').exists())

    def test_existing_output_preserved(self):
        self.out.mkdir()
        (self.out/'evidence').write_text('KEEP')
        p=self.run_cli()
        self.assertEqual(p.returncode,2)
        self.assertEqual((self.out/'evidence').read_text(),'KEEP')

    def test_nested_sdk_path_refused(self):
        p=self.run_cli(out=self.sdk/'new-output')
        self.assertEqual(p.returncode,2)
        self.assertFalse((self.sdk/'new-output').exists())

    def test_missing_sdk_refused(self):
        p=self.run_cli(sdk=self.root/'missing')
        self.assertEqual(p.returncode,2)

    def test_output_parent_absent_refused(self):
        p=self.run_cli(out=self.root/'no-parent'/'output')
        self.assertEqual(p.returncode,2)

    def test_symlinked_sdk_refused(self):
        alias=self.root/'alias'
        alias.symlink_to(self.sdk, target_is_directory=True)
        p=self.run_cli(sdk=alias)
        self.assertEqual(p.returncode,2)

    def test_missing_xmi_not_success(self):
        (self.sdk/'omit.txt').write_text('1')
        p=self.run_cli()
        self.assertEqual(p.returncode,1)
        report=json.loads((self.out/'oorexx-mvs-host-report.json').read_text())
        self.assertFalse(report['xmit_present'])
        self.assertFalse(report['guest_qualified'])

    def test_consumer_failure_not_success(self):
        (self.sdk/'fail.txt').write_text('1')
        p=self.run_cli()
        self.assertEqual(p.returncode,1)
        self.assertFalse(self.out.exists())

    def test_unknown_profile_rejected(self):
        self.assertNotEqual(self.run_cli(profile='tso-zos64-v1').returncode,0)
        self.assertFalse(self.out.exists())

    def test_relative_sdk_rejected(self):
        self.assertEqual(self.run_cli(sdk='some/sdk').returncode,2)

    def test_relative_output_rejected(self):
        self.assertEqual(self.run_cli(out='output').returncode,2)

if __name__=='__main__': unittest.main(verbosity=2)
