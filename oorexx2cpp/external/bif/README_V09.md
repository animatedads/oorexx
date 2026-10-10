# v0.9: v0.25 language ABI compatibility / safe native retry

**Scope:** independent ooRexx-authored BIF source-rule converter and C++
add-on. Same 81-name route inventory as v0.8; no coverage percentage bump is
claimed. This revision fixes a real fallback-safety bug rather than adding
new synthetic route entries.

**Important:** this does not patch rx2cpp v0.25. It tests against the v0.25
native `rx::Value` header and keeps the compiler's BIF whitelist untouched.

See `V025_COMPATIBILITY.md` and `QUALIFICATION_V09.md` for exact evidence.
