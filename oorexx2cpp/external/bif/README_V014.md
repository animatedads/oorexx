# BIF v0.14 scoped caller-state release

Targets supplied rx2cpp v0.28.1. Adds an optional `rxbif_v0281::ScopedActivation` and `ThreadRouter`, preventing concurrent reuse of the same activation/BIF runtime across threads and preserving nested scope and per-invocation numeric state. This is a separate BIF-only add-on; rx2cpp and extlib are unchanged.
