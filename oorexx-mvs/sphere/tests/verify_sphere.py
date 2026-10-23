#!/usr/bin/env python3
"""Structure-only verifier for oo-rexx-mvs Gopher sphere. Not target qualification."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PK = ROOT / "packs" / "oo-rexx-mvs"

def main():
    def load(p): return json.loads(p.read_text(encoding="utf-8"))
    profile = load(ROOT / "profiles" / "oo-rexx-mvs.json")
    sphere = load(PK / "00-sphere.json")
    policy = load(PK / "01-access-policy.json")
    ledger = load(ROOT / "SOURCE_AUTHORITY.json")
    assert profile["id"] == sphere["id"] == "oo-rexx-mvs"
    assert sphere["kind"] == "sphere" and profile["kind"] == "profile"
    assert "packs/oo-rexx-mvs" in profile["packs"]
    assert policy["id"] == sphere["access_policy"]
    assert all(r["actions"] == ["read"] for r in policy["rules"])
    sections = {s["id"] for s in sphere["sections"]}
    paths = sorted((PK / "articles").glob("*.json"))
    articles = [load(p) for p in paths]
    ids = {a["id"] for a in articles}
    assert len(articles) == len(ids) == 9
    assert set(sphere["start_here"]) <= ids
    for a in articles:
        assert a["kind"] == "article" and a["sphere"] == sphere["id"]
        assert a["section"] in sections and a["summary"] and a["invariants"]
        assert a["provenance"] and set(a["related"]) <= ids
        assert a["authority"] == "project-artifact"
    corpus = load(PK / "corpora" / "oo-rexx-mvs.continuity.json")
    assert corpus["sphere"] == sphere["id"] and len(corpus["records"]) >= 8
    assert ledger["upstream_pins"]["ooRexx"] == "de1db87f486d430d1faa9151b8a2d5f328ab70f2"
    assert len(ledger["distribution_archives"]) == 3
    assert all(len(x["sha256"]) == 64 for x in ledger["distribution_archives"])
    claims = "\n".join(a["summary"] + " " + " ".join(a["invariants"]) for a in articles)
    assert "190/199" in claims and "MVS 3.8J" in claims
    assert "NOT_RUN" in claims or "not been run" in claims
    print("PASS Gopher oo-rexx-mvs v0.1 static structure (9 articles, 9 continuity rules)")

if __name__ == "__main__":
    main()
