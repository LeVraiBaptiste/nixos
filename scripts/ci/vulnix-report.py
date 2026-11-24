#!/usr/bin/env python3
"""Turn `vulnix --json` output into a Markdown section, highest CVSS first.

Usage: vulnix-report.py host vulnix.json [runtime-drvs.txt]
With the output of runtime-drvs.py, only packages in the runtime closure are
listed, the others are just counted.
"""
import json
import re
import sys

host, path = sys.argv[1], sys.argv[2]
# fish completions generated from a package's man pages repeat its findings
findings = [
    f
    for f in json.load(open(path))
    if f["affected_by"] and not f["name"].endswith("_fish-completions")
]

build_only = 0
if len(sys.argv) > 3:
    # Match on name-version: vulnix keeps one .drv per name, not always the one installed
    runtime = {
        re.sub(r"^/nix/store/[a-z0-9]+-|\.drv$", "", line.strip())
        for line in open(sys.argv[3])
    }
    kept = [f for f in findings if f["name"] in runtime]
    build_only = len(findings) - len(kept)
    findings = kept


def worst(f):
    # cvssv3_basescore also scores the whitelisted CVEs
    return max((f["cvssv3_basescore"].get(c, 0) for c in f["affected_by"]), default=0)


findings.sort(key=worst, reverse=True)
high = sum(1 for f in findings if worst(f) >= 7)

extra = f" {build_only} more only in build dependencies." if build_only else ""

print(f"## {host}\n")
if not findings:
    print(f"No known vulnerability.{extra}\n")
    sys.exit()

print(f"{len(findings)} affected packages, {high} with a CVSS ≥ 7.{extra}\n")
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
