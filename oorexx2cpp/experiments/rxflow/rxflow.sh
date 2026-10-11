#!/usr/bin/env bash
# OS backstop under the Rexx layers: no network, read-only filesystem, scratch tmpfs, stdin closed.
exec unshare -rmn bash -c 'mount -o remount,ro,bind / / && exec "$@"' _ "$@" </dev/null
