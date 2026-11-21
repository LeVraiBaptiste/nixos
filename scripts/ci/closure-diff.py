#!/usr/bin/env python3
"""Markdown list of package version changes between two system derivations.

Works on .drv closures, so it needs evaluation only (nothing is built). Build-time
dependencies are included; sources, patches and other plain files are skipped.
"""
import re
import subprocess
import sys
from collections import defaultdict

# Store names that are files rather than packages
SKIP = re.compile(r"\.(tar|tgz|zip|patch|diff|cabal|sh|py|json|toml|conf|xz|gz|bz2|deb|rpm|AppImage)\b|-source$|-src$|_fish-completions$")


def packages(drv):
    out = subprocess.run(["nix-store", "-qR", drv], check=True, capture_output=True, text=True).stdout
    versions = defaultdict(set)
    for path in out.split():
        name = path.split("-", 1)[1].removesuffix(".drv")
        if SKIP.search(name):
            continue
        # Same split as builtins.parseDrvName: the version starts at the first "-<digit>"
        m = re.match(r"(.+?)-(\d.*)$", name)
        if m:
            versions[m.group(1)].add(m.group(2))
    return versions


def fmt(versions):
    return ", ".join(sorted(versions)) or "-"


old, new = packages(sys.argv[1]), packages(sys.argv[2])
changed = sorted(p for p in old.keys() & new.keys() if old[p] != new[p])
added = sorted(new.keys() - old.keys())
removed = sorted(old.keys() - new.keys())

if not (changed or added or removed):
    print("No package change.")
    sys.exit()

print("| Package | Before | After |")
print("|---|---|---|")
for p in changed:
    print(f"| {p} | {fmt(old[p])} | {fmt(new[p])} |")
for p in added:
    print(f"| {p} | - | {fmt(new[p])} |")
for p in removed:
    print(f"| {p} | {fmt(old[p])} | - |")
