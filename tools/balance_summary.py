#!/usr/bin/env python3
"""Summarise tools/balance.ps1 output: python balance_summary.py <out dir>.
Reads <dir>/*/meta.json + host.json, prints and writes summary.md and summary.csv (stdlib only)."""
import csv
import json
import sys
from pathlib import Path


def main():
    out = Path(sys.argv[1])
    rows = []
    for meta_f in sorted(out.glob("*/meta.json")):
        d = meta_f.parent
        meta = json.loads(meta_f.read_text(encoding="utf-8-sig"))
        host = d / "host.json"
        res = None
        if host.exists():
            res = json.loads(host.read_text(encoding="utf-8-sig")).get("result")
        tag = meta.get("tag") or ""
        row = {"players": meta["players"], "shift": meta["shift"], "map": meta["map"] + ("/" + tag if tag else ""),
               "difficulty": meta["difficulty"], "run": meta["run"]}
        if res:
            secs = float(meta["shift_seconds"])
            target = int(res["target"])
            earned = int(res["earned"])
            row.update(served=res["served"], expired=res["failed"], coins=earned, target=target,
                       met="yes" if res["met"] else "no",
                       cpm=round(earned * 60.0 / secs, 1) if secs else 0,
                       ratio=round(earned / target, 2) if target else 0)
        else:
            row.update(served="", expired="", coins="", target="", met="FAILED", cpm="", ratio="")
        rows.append(row)
    rows.sort(key=lambda r: (r["players"], r["shift"], r["map"], r["difficulty"], r["run"]))
    cols = [("players", "players"), ("shift", "shift"), ("map", "map"), ("difficulty", "difficulty"), ("run", "run"),
            ("served", "orders served"), ("expired", "orders expired"), ("coins", "coins earned"),
            ("target", "target"), ("met", "target met"), ("cpm", "coins/min"), ("ratio", "throughput ratio")]
    with open(out / "summary.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([c[1] for c in cols])
        for r in rows:
            w.writerow([r[c[0]] for c in cols])
    lines = ["| " + " | ".join(c[1] for c in cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        lines.append("| " + " | ".join(str(r[c[0]]) for c in cols) + " |")
    md = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(md, encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
