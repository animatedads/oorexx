# Source evidence reconciliation (2026-10-23)

The dev20 source archive retains translation matrices and logs not yet reflected
in the GitHub source tree.  These are *historical* toolchain observations.

Source: oorexx-mvs24-cfront-dev20-source.zip
SHA-256: 18d7996bd649e7449bad116f9fdda48f4767a62b3ac91ad05ccf1aa8dae9f6ad

Restored evidence:
- dev15-new-units.tsv: ten dev15 newly qualified core units.
- dev16-residual-15.tsv: six newly cleared and nine remaining units (despite the
  historical filename '15', the 15 rows comprise both outcomes).
- verified-summary.json: cfront return codes, cc370 return codes and assembler
  byte counts for those 15 rows.

These are not cfront stderr diagnostics for the nine remaining units.
Missing first-failure logs must be regenerated with the pinned source/toolchain
and cannot be inferred from the return codes alone.

No new target MVS, modern z/OS, cfront or cc370 execution was performed by this
publication. The inherited qualification remains 190/199.
