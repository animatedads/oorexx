#!/bin/sh
# Source retrieval helper; deliberately never changes an existing checkout.
set -eu
PIN=de1db87f486d430d1faa9151b8a2d5f328ab70f2
DEST=${1:-}
if [ -z "$DEST" ]; then echo 'Usage: fetch-pinned-oorexx.sh DESTINATION' >&2; exit 2; fi
if [ -e "$DEST" ]; then echo 'Refusing to replace existing destination' >&2; exit 2; fi
git clone https://github.com/ooRexx/ooRexx.git "$DEST"
git -C "$DEST" checkout --detach "$PIN"
SCRIPT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
python3 "$SCRIPT/verify-pinned-source.py" "$DEST"
