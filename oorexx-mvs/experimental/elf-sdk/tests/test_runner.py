#!/usr/bin/env python3
"""Fake SDK receipt controls. Never treat these as native compiler tests."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parent.parent / "run-sdk-host-smoke.py"

# Mock produces the *schema* of the real installed SDK 0.1.0 consumer; it does
# not compile, assemble, link or create a genuine TSO load module.
CONSUMER = r'''import argparse, hashlib, json, pathlib, sys, time
p = argparse.ArgumentParser()
for flag in ('sdk', 'profile', 'tso-source', 'member-prefix', 'out'):
    p.add_argument('--' + flag, required=True)
a=p.parse_args(); sdk=pathlib.Path(a.sdk)
def hashit(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if (sdk/'timeout.txt').exists():time.sleep(3)
if (sdk/'fail.txt').exists():sys.exit(31)
out=pathlib.Path(a.out); d=out/a.profile; d.mkdir(parents=True)
if (sdk/'omit.txt').exists():sys.exit(0)
source=d/'consumer.c';source.write_bytes(pathlib.Path(a.tso_source).read_bytes())
elf=d/'consumer.elf';elf.write_bytes(b'FAKE ELF NOT OBJECT')
deck=d/'consumer.obj';deck.write_bytes(b'FAKE DECK')
suffix='24' if a.profile=='tso-zos24-v1' else '31'
xmi=d/(a.member_prefix+suffix+'.XMI');xmi.write_bytes(b'FAKE XMIT')
link={'xmit_sha256':hashit(xmi),'member':a.member_prefix+suffix,
      'amode':int(suffix),'rmode':'24' if suffix=='24' else 'ANY'}
if (sdk/'wrong-member.txt').exists():link['member']='WRONG'
if (sdk/'wrong-amode.txt').exists():link['amode']=64
if (sdk/'wrong-xmit.txt').exists():link['xmit_sha256']='0'*64
result={'format':'mainframe-compiler-sdk-consumer-v1',
 'sdk_manifest_sha256':hashit(sdk/'SDK-MANIFEST.json'),
 'profiles':{a.profile:{'source_sha256':hashit(source),'elf_sha256':hashit(elf),
                       'native_deck_sha256':hashit(deck),
                       'source_native_links':{'default':link}}},
 'qualification':'host compile/link/package only; no new guest execution'}
if (sdk/'wrong-source.txt').exists():result['profiles'][a.profile]['source_sha256']='0'*64
if (sdk/'wrong-format.txt').exists():result['format']='wrong'
(out/'result.json').write_text(json.dumps(result))
if (sdk/'missing-deck.txt').exists():deck.unlink()
if (sdk/'symlink-xmit.txt').exists():
    backup=d/'real.xmi'; xmi.rename(backup); xmi.symlink_to(backup)
'''

class SdkSmokeTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='rx-sdk21-')
        self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.sdk=self.root/'sdk'
        (self.sdk/'tools').mkdir(parents=True)
        (self.sdk/'SDK-MANIFEST.json').write_text('{"fake":"never a real SDK"}\n')
        (self.sdk/'tools'/'compiler_sdk_consume.py').write_text(CONSUMER)
        self.out=self.root/'new-output'

    def go(self,profile='tso-zos31-v1',**kw):
        args={'sdk':str(self.sdk),'profile':profile,'out':str(self.out)}
        args.update(kw)
        argv=[sys.executable,str(SCRIPT)]
        for k,v in args.items():argv+=['--'+k.replace('_','-'),str(v)]
        return subprocess.run(argv,capture_output=True,text=True,timeout=10)

    def flag(self,name):
        (self.sdk/name).write_text('1')

    def test_tso31_receipt(self):
        r=self.go();self.assertEqual(r.returncode,0,r.stderr)
        d=json.loads((self.out/'oorexx-mvs-host-report.json').read_text())
        self.assertTrue(d['host_packaging_verified'])
        self.assertTrue(d['xmit_present'])
        self.assertFalse(d['guest_qualified']);self.assertFalse(d['guest_executed'])
        self.assertIsNone(d['guest_return_code'])
        self.assertEqual(d['schema'],'oorexx.mvs.elf_sdk.host_smoke/2')
        self.assertEqual(d['consumer_exit_code'],0)

    def test_tso24_receipt(self):
        r=self.go(profile='tso-zos24-v1');self.assertEqual(r.returncode,0,r.stderr)
        self.assertTrue((self.out/'tso-zos24-v1'/'RXMVS24.XMI').exists())

    def assert_fail(self,flag,reason=None):
        self.flag(flag);r=self.go();self.assertEqual(r.returncode,1,r.stdout+r.stderr)
        d=json.loads((self.out/'oorexx-mvs-host-report.json').read_text())
        self.assertFalse(d['host_packaging_verified']);self.assertFalse(d['guest_qualified'])
        if reason:self.assertIn(reason,d['host_verification_reason'])

    def test_missing_output_refused(self):self.assert_fail('omit.txt','Missing')
    def test_wrong_source_digest_refused(self):self.assert_fail('wrong-source.txt','source_sha256')
    def test_wrong_manifest_format_refused(self):self.assert_fail('wrong-format.txt','format')
    def test_wrong_native_member_refused(self):self.assert_fail('wrong-member.txt','member')
    def test_wrong_amode_refused(self):self.assert_fail('wrong-amode.txt','AMODE')
    def test_wrong_xmit_digest_refused(self):self.assert_fail('wrong-xmit.txt','XMIT')
    def test_missing_deck_refused(self):self.assert_fail('missing-deck.txt','Missing')
    def test_symlink_xmit_refused(self):self.assert_fail('symlink-xmit.txt','symlinked')

    def test_consumer_failure(self):
        self.flag('fail.txt');r=self.go();self.assertEqual(r.returncode,1)
        self.assertFalse(self.out.exists())

    def test_timeout_refused(self):
        self.flag('timeout.txt');r=self.go(timeout_sec=0.15)
        self.assertEqual(r.returncode,1,r.stderr)
        self.assertFalse(json.loads((self.out/'oorexx-mvs-host-report.json').read_text())['guest_qualified']) if self.out.is_dir() else None

    def test_existing_output_preserved(self):
        self.out.mkdir();(self.out/'evidence').write_text('KEEP')
        r=self.go();self.assertEqual(r.returncode,2)
        self.assertEqual((self.out/'evidence').read_text(),'KEEP')

    def test_sdk_overlap_refused(self):
        r=self.go(out=self.sdk/'output');self.assertEqual(r.returncode,2)

    def test_source_overlap_refused(self):
        r=self.go(out=SCRIPT.parent/'output');self.assertEqual(r.returncode,2)

    def test_missing_sdk(self):self.assertEqual(self.go(sdk=self.root/'missing').returncode,2)
    def test_missing_output_parent(self):self.assertEqual(self.go(out=self.root/'missing'/'output').returncode,2)
    def test_symlinked_sdk(self):
        alias=self.root/'alias';alias.symlink_to(self.sdk,target_is_directory=True)
        self.assertEqual(self.go(sdk=alias).returncode,2)
    def test_relative_sdk(self):self.assertEqual(self.go(sdk='rel').returncode,2)
    def test_relative_output(self):self.assertEqual(self.go(out='rel').returncode,2)
    def test_unsupported_profile(self):self.assertNotEqual(self.go(profile='tso-zos64-v1').returncode,0)
    def test_non_positive_timeout(self):self.assertEqual(self.go(timeout_sec=0).returncode,2)
    def test_too_large_timeout(self):self.assertEqual(self.go(timeout_sec=5000).returncode,2)

if __name__=='__main__':unittest.main(verbosity=2)
