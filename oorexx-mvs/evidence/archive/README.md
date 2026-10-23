# Historical dev20 translation evidence archive

This archive restores **38 files** from the exact `oorexx-mvs24-cfront-dev20-source.zip`
delivery, including all retained dev14 matrix, dev17 tests, dev15/dev16
compiler transcript fragments and source SHA-256 ledgers that were not in
the published GitHub tree.

* `dev20-retained-evidence.zip` SHA-256:
  `06d40963c83e60dbcbc7b83fad6d6b5939b9866a50636ae8e009691b7cebe6d1`
* Original dev20 source archive SHA-256:
  `18d7996bd649e7449bad116f9fdda48f4767a62b3ac91ad05ccf1aa8dae9f6ad`
* Contents include 32 successful-unit `*.cfront.log` and
  `*.cc370.log` files, plus the dev14 matrix, dev17 tests,
  `residual.tsv`, and the historical SHA manifests.
* The 38 original member paths and bytes are retained unchanged in
  `oorexx-mvs/` relative locations inside this bundle.

**Do not treat these logs as fresh compiler runs.** The transcript fragments
correspond to successful units and do not supply the first fatal diagnostics
for the nine remaining cfront failures. The existing dev16 frontier is
190/199 and native guest execution has not been established.

For direct repository inspection, the concise dev15 and dev16 matrices and
the dev16 JSON summary are also checked into `evidence/` as text.
