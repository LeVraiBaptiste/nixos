#!/usr/bin/env python3
"""Print the derivations whose outputs end up in a system's runtime closure,
without building it.

The real closure needs the built toplevel. Instead, walk it from the top:
a path in cache.nixos.org gives its exact references in its narinfo; a path
that isn't there (config files, units, local overlays) is assumed to reference
every input of its derivation, except stdenv, which only serves the build.
This over-approximates a bit, but drops the compilers and build tools that
make a vulnix scan of the .drv so noisy.

Usage: runtime-drvs.py /nix/store/...-nixos-system-host.drv
"""
import json
import subprocess
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

CACHE = "https://cache.nixos.org"
STORE = "/nix/store/"


def base(p):
    return p.removeprefix(STORE)


def references(path):
    """References of a store path in the binary cache, or None if it isn't there."""
    url = f"{CACHE}/{path.split('-', 1)[0]}.narinfo"
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                for line in r.read().decode().splitlines():
                    if line.startswith("References:"):
                        return line.split()[1:]
                return []
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except (urllib.error.URLError, TimeoutError):
            pass
    sys.exit(f"cannot query {url}")


toplevel = sys.argv[1]
show = json.loads(
    subprocess.check_output(["nix", "derivation", "show", "-r", toplevel])
)
drvs = {base(k): v for k, v in show.get("derivations", show).items()}

# output path -> derivation producing it
producer = {}
for name, d in drvs.items():
    for out in d["outputs"].values():
        if "path" in out:
            producer[base(out["path"])] = name


def inputs(name):
    d = drvs[name]
    ins = d["inputs"] if "inputs" in d else {"drvs": d["inputDrvs"], "srcs": d["inputSrcs"]}
    for dep, spec in ins["drvs"].items():
        dep = base(dep)
        if dep.split("-", 1)[1].startswith("stdenv-"):
            continue
        outputs = spec["outputs"] if isinstance(spec, dict) else spec
        for o in outputs:
            # floating content-addressed outputs have no known path yet
            if "path" in drvs[dep]["outputs"][o]:
                yield base(drvs[dep]["outputs"][o]["path"])
    yield from (base(s) for s in ins["srcs"])


start = [base(o["path"]) for o in drvs[base(toplevel)]["outputs"].values() if "path" in o]
seen, frontier = set(start), start
with ThreadPoolExecutor(32) as pool:
    while frontier:
        nxt = []
        for path, refs in zip(frontier, pool.map(references, frontier)):
            if refs is None:
                refs = list(inputs(producer[path])) if path in producer else []
            for r in refs:
                if r not in seen:
                    seen.add(r)
                    nxt.append(r)
        frontier = nxt

for name in sorted({producer[p] for p in seen if p in producer}):
    print(STORE + name)
