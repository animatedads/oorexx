# Publishing the dev18 translation sources

The original dev18 source bundle has 19 translation-related files. The repository tracks expected Git blob identities in `evidence/translation-source-blobs.json`.

## Source bundle

Use the archive `oorexx-mvs-translation-scripts-dev18.zip` (SHA-256 `2c97eb99e5c2c5a0057132d0c6832e1dcbfa2fec9655871ea9134aaccfa4655c`). Its paths begin with `oorexx-mvs/`. It contains the **actual translation code**, including the large dev13 Python transform, dev15/dev16 Bash drivers, and three historical cfront source replacement files. The ZIP is a publication input, not an MVS binary or translation qualification result.

Run from a machine with a GitHub-authenticated working clone of `animatedads/oorexx`:

```sh
python3 oorexx-mvs/tools/publish-translation-sources.py /path/to/oorexx-mvs-translation-scripts-dev18.zip .
```

This previews and verifies all nineteen blobs, including files already checked in.

```sh
python3 oorexx-mvs/tools/publish-translation-sources.py /path/to/oorexx-mvs-translation-scripts-dev18.zip . --push
```

This writes only missing paths, commits just those paths, and attempts a **normal fast-forward push** to `main`. It refuses a dirty repository, the wrong branch, a changed existing source file, incorrect archive SHA-256, mismatched Git blobs, or unsafe path traversal. No `--force` push is used. You may use `--apply` instead to write sources without committing.

## Verification

Check the tracked files on GitHub against the expected blob IDs. Do **not** equate this source publication with a new cfront/cc370 run. The translation frontier is **190/199** and target MVS link/JES execution remains unqualified.
