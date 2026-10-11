"""Focused API catch-transform tests: host-only, no MVS compiler claim."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANSFORM = ROOT / 'dev16_api_unwind.py'


class ApiGuardTest(unittest.TestCase):
    def transform(self, source):
        with tempfile.TemporaryDirectory() as temp:
            target = Path(temp) / 'interpreter_api_CallContextStubs_cpp.ii'
            target.write_text(source)
            run = subprocess.run([sys.executable, str(TRANSFORM), temp],
                                 capture_output=True, text=True, check=True)
            result = target.read_text()
        return result, run.stdout

    def test_single_native_activation_catch_release_is_idempotent(self):
        result, out = self.transform('''
class NativeActivation {};
int call() {
    try { return 2; } catch (NativeActivation *) { return 3; }
}
''')
        self.assertIn('interpreter_api_CallContextStubs_cpp.ii 1', out)
        self.assertIn('mvsApiGuard1.release();', result)
        self.assertIn('if (armed) { armed = 0; mvsUnwindPop(&frame); }', result)
        self.assertIn('~MvsNativeUnwindGuard() { release(); }', result)
        self.assertNotIn('mvsUnwindPop(&mvsApiGuard1.frame);', result)

    def test_two_catches_get_distinct_guards(self):
        result, out = self.transform('''
class NativeActivation {};
int call() {
  try { act1(); } catch (NativeActivation *) { on1(); }
  try { act2(); } catch (NativeActivation *) { on2(); }
  return 0;
}
''')
        self.assertIn('ii 2', out)
        self.assertEqual(result.count('mvsApiGuard1.release();'), 1)
        self.assertEqual(result.count('mvsApiGuard2.release();'), 1)

    def test_no_rewrite_when_not_a_matching_catch(self):
        text = 'int call(){ try { go(); } catch (int e) { fail(e); } }'
        result, out = self.transform(text)
        self.assertEqual(result, text)
        self.assertEqual(out, '')

    def test_repeated_transform_is_stable(self):
        result, _ = self.transform('int f(){try{a();}catch (NativeActivation *){b();}}')
        again, out = self.transform(result)
        self.assertEqual(again, result)
        self.assertEqual(out, '')


if __name__ == '__main__':
    unittest.main(verbosity=2)
