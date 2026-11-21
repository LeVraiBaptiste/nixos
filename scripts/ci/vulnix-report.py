#!/usr/bin/env python3
"""Turn `vulnix --json` output into a Markdown section, highest CVSS first."""
import json
import sys

host, path = sys.argv[1], sys.argv[2]
findings = [f for f in json.load(open(path)) if f["affected_by"]]


def worst(f):
    return max(f["cvssv3_basescore"].values(), default=0)


findings.sort(key=worst, reverse=True)
high = sum(1 for f in findings if worst(f) >= 7)

print(f"## {host}\n")
if not findings:
    print("No known vulnerability.\n")
    sys.exit()

print(f"{len(findings)} affected packages, {high} with a CVSS ≥ 7.\n")
print("<details><summary>Details</summary>\n")
print("| CVSS | Package | CVEs |")
print("|---|---|---|")
for f in findings:
    scores = f["cvssv3_basescore"]
    cves = ", ".join(
        f"[{c}](https://nvd.nist.gov/vuln/detail/{c}) ({scores.get(c, '?')})"
        for c in sorted(f["affected_by"], key=lambda c: scores.get(c, 0), reverse=True)
    )
    print(f"| {worst(f) or '?'} | {f['name']} | {cves} |")
print("\n</details>\n")
