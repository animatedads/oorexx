#!/usr/bin/env python3
"""Tests dependency discovery only, not the functional external library host."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile

RESOLVER = Path(__file__).resolve().parents[1] / 'tools' / 'resolve_extlib_root.py'


class ResolveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'work' / 'oorexx2cpp'
        self.repo.mkdir(parents=True)
        self.stage = self.root / 'build'
        self.header = 'include/rx2cpp_extlib.hpp'
        self.base_env = {k: v for k, v in os.environ.items()
                         if k not in ('RX2CPP_EXTLIB_ROOT', 'RX2CPP_EXTLIB_ARCHIVE')}

    def call(self, **environment):
        return subprocess.run(['python3', str(RESOLVER), '--repo-root',
                               str(self.repo), '--staging', str(self.stage)],
                              env={**self.base_env, **environment},
                              capture_output=True, text=True)

    def test_missing_is_failure_not_skip_or_success(self):
        result = self.call()
        self.assertEqual(result.returncode, 78)
        self.assertIn('MISSING_DEPENDENCY', result.stderr)
        self.assertEqual(result.stdout, '')

    def test_explicit_unpacked_root(self):
        folder = self.root / 'approved'
        (folder / 'include').mkdir(parents=True)
        (folder / self.header).write_text('// fixture\n')
        result = self.call(RX2CPP_EXTLIB_ROOT=str(folder))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()), folder)

    def test_explicit_zip_auto_extracts(self):
        archive = self.root / 'approved.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('release/' + self.header, '// fixture\n')
        result = self.call(RX2CPP_EXTLIB_ARCHIVE=str(archive))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((Path(result.stdout.strip()) / self.header).is_file())

    def test_local_standard_zip(self):
        archive = self.repo.parent / 'rx2cpp_extlib_v0.1(1).zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('rx2cpp_extlib_v0.1b/' + self.header, '// fixture\n')
        result = self.call()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unsafe_zip_is_rejected(self):
        archive = self.root / 'evil.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('../../pwn', 'x')
            z.writestr(self.header, '// fixture\n')
        result = self.call(RX2CPP_EXTLIB_ARCHIVE=str(archive))
        self.assertEqual(result.returncode, 78)
        self.assertIn('unsafe ZIP entry', result.stderr)
        self.assertFalse((self.root / 'pwn').exists())

    def test_ambiguous_candidates_rejected(self):
        for name in ('rx2cpp_extlib_v0.1', 'rx2cpp_extlib_v0.1b'):
            path = self.repo.parent / name / 'include'
            path.mkdir(parents=True)
            (path / 'rx2cpp_extlib.hpp').write_text('// fixture\n')
        result = self.call()
        self.assertEqual(result.returncode, 78)
        self.assertIn('ambiguous', result.stderr)

    def test_bad_root_not_silently_replaced(self):
        result = self.call(RX2CPP_EXTLIB_ROOT='/surely/nonexistent/rx2cpp')
        self.assertEqual(result.returncode, 78)
        self.assertIn('does not exist', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
