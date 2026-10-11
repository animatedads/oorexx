#!/usr/bin/env python3
"""Host-only regression tests for the dev19 translation-driver preflight.

Does not simulate or claim cfront/cc370 compilation. The fake binaries are
never executed: this exercises early rejection and non-destructive admission.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

DRIVER = Path(__file__).resolve().parent.parent / "oorexx-mvs24-cfront-bulkpass-dev16.sh"
RESIDUALS = (
    "interpreter/execution/NativeActivation.cpp",
    "interpreter/instructions/CommandIOConfiguration.cpp",
    "interpreter/memory/Setup.cpp",
    "interpreter/package/LibraryPackage.cpp",
    "interpreter/runtime/InternalPackage.cpp",
    "interpreter/runtime/Interpreter.cpp",
    "interpreter/runtime/RexxUtilCommon.cpp",
    "interpreter/streamLibrary/FileNative.cpp",
    "interpreter/streamLibrary/StreamNative.cpp",
)


def git(root, *args):
    env = dict(os.environ, GIT_AUTHOR_NAME="MVS Test", GIT_AUTHOR_EMAIL="mvs@example.invalid",
               GIT_COMMITTER_NAME="MVS Test", GIT_COMMITTER_EMAIL="mvs@example.invalid")
    return subprocess.check_output(["git", "-C", str(root), *args], env=env,
                                   stderr=subprocess.DEVNULL, text=True).strip()


class PreflightTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mvs19-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / "oorexx-src"
        self.src.mkdir()
        git(self.src, "init", "-q")
        for rel in RESIDUALS:
            p = self.src / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("/* synthetic source only */\n")
        git(self.src, "add", ".")
        git(self.src, "commit", "-qm", "synthetic test source")
        self.pin = git(self.src, "rev-parse", "HEAD")
        self.cfront = self.root / "cfront-src"
        self.cfront.mkdir()
        (self.cfront / "cfront").write_text("#!/bin/sh\nexit 99\n")
        (self.cfront / "cfront").chmod(0o755)
        self.cc370 = self.root / "cc370-src"
        (self.cc370 / "build" / "gcc").mkdir(parents=True)
        (self.cc370 / "build" / "gcc" / "xgcc").write_text("#!/bin/sh\nexit 99\n")
        (self.cc370 / "build" / "gcc" / "xgcc").chmod(0o755)
        self.work = self.root / "output"
        (self.work / "logs").mkdir(parents=True)
        (self.work / "logs" / "previous-evidence.log").write_text("RETAIN ME")

    def run_preflight(self, **overrides):
        env = dict(os.environ,
                   OOREXX_SRC=str(self.src), CFRONT_SRC=str(self.cfront),
                   CC370_SRC=str(self.cc370), WORK=str(self.work),
                   PIN=self.pin, SWEEP_MODE="residual", MVS_PREFLIGHT_ONLY="1")
        env.update({key: str(value) for key, value in overrides.items()})
        return subprocess.run(["bash", str(DRIVER)], env=env,
                              text=True, capture_output=True, timeout=12)

    def assert_evidence_untouched(self):
        self.assertEqual((self.work / "logs" / "previous-evidence.log").read_text(), "RETAIN ME")

    def test_success_residual_nine_and_no_modification(self):
        r = self.run_preflight()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("sweep_mode=residual selected_units=9", r.stdout)
        self.assertIn("PASS MVS source/toolchain/workdir preflight", r.stdout)
        self.assertEqual(git(self.src, "rev-parse", "HEAD"), self.pin)
        self.assert_evidence_untouched()

    def test_wrong_head_does_not_checkout(self):
        r = self.run_preflight(PIN="a" * 40)
        self.assertEqual(r.returncode, 21)
        self.assertIn("checkout left untouched", r.stderr)
        self.assertEqual(git(self.src, "rev-parse", "HEAD"), self.pin)
        self.assert_evidence_untouched()

    def test_dirty_tree_refused(self):
        (self.src / RESIDUALS[0]).write_text("modified\n")
        r = self.run_preflight()
        self.assertEqual(r.returncode, 21)
        self.assertIn("modifications", r.stderr)
        self.assert_evidence_untouched()

    def test_untracked_tree_refused(self):
        (self.src / "UNTRACKED").write_text("new")
        r = self.run_preflight()
        self.assertEqual(r.returncode, 21)
        self.assert_evidence_untouched()

    def test_missing_cc370_refused(self):
        (self.cc370 / "build" / "gcc" / "xgcc").unlink()
        r = self.run_preflight()
        self.assertEqual(r.returncode, 23)
        self.assert_evidence_untouched()

    def test_missing_cfront_refused(self):
        (self.cfront / "cfront").unlink()
        r = self.run_preflight()
        self.assertEqual(r.returncode, 22)
        self.assert_evidence_untouched()

    def test_missing_residual_source_refused(self):
        (self.src / RESIDUALS[2]).unlink()
        r = self.run_preflight()
        self.assertEqual(r.returncode, 21)  # dirty tracked source is refused first
        self.assert_evidence_untouched()

    def test_unknown_mode_refused(self):
        r = self.run_preflight(SWEEP_MODE="oops")
        self.assertEqual(r.returncode, 24)
        self.assertIn("Unsupported SWEEP_MODE", r.stderr)
        self.assert_evidence_untouched()

    def test_overlapping_output_root_refused(self):
        r = self.run_preflight(WORK=self.src)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Unsafe WORK directory", r.stderr)
        self.assert_evidence_untouched()

    def test_parent_of_checkout_as_output_refused(self):
        r = self.run_preflight(WORK=self.root)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Unsafe WORK directory", r.stderr)
        self.assert_evidence_untouched()

    def test_symlinked_log_output_refused(self):
        (self.work / "logs" / "previous-evidence.log").unlink()
        (self.work / "logs").rmdir()
        (self.work / "logs").symlink_to(self.src, target_is_directory=True)
        r = self.run_preflight()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("symbolic output directory", r.stderr)

    def test_unwind_runtime_path_wired(self):
        txt = DRIVER.read_text()
        self.assertIn('UNWIND_SOURCE="$SCRIPT_DIR/runtime/MvsUnwind.cpp"', txt)
        self.assertNotIn('git -C "$OOREXX_SRC" checkout', txt)


if __name__ == "__main__":
    unittest.main(verbosity=2)
