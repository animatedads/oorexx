# dev18 translation source publication

The canonical source-oriented checkpoint is
`oorexx-mvs-github-ready-dev18.zip` (SHA-256
`5c15f8ac55b47d05d471d13d80f9a2e53da06ae7c5312b79e803e1d58ae9c094`).

Source files committed individually to GitHub to date:

- `dev14_post_transform.py`
- `dev15_post_transform.py`
- `dev15_extra.py`
- `dev16_api_unwind.py`
- `dev16_extra.py`
- `cfront-oorexx-mvs24.patch`
- `mvs370.size`

This is **not yet the complete dev18 source tree**. In particular, the
`dev13_transform.py` base transformation, the 80 KB dev16 main shell
pipeline, patched cfront source replacements and API shape definitions
must still be committed individually from the verified checkpoint.

## Source recovery and checking

This repository includes `tools/import-dev18-sources.py`. It verifies the
entire 70-file original checkpoint and its embedded 69-file source manifest
before extracting. Extraction does not overwrite differing files.

From a checkout of this repository, with the original checkpoint ZIP
available locally:

```sh
python3 oorexx-mvs/tools/import-dev18-sources.py oorexx-mvs-github-ready-dev18.zip
python3 oorexx-mvs/tools/import-dev18-sources.py oorexx-mvs-github-ready-dev18.zip --extract .
```

Review `git status` before staging. Generated C, S/370 assembler and
the patched cfront executable are deliberately excluded from source
publication; they remain in the full dev18 artifact.

**Not a runtime qualification claim.** Current translation frontier
remains 190/199 on Linux; no MVS linking or JES execution has been asserted.
