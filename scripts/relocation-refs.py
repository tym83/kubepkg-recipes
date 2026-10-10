#!/usr/bin/env python3
"""Lists the artifacts a published index keeps under an old registry path,
with where each goes under the new one: "<from> <to>" per line, for oras cp.

    relocation-refs.py index.yaml oci://ghcr.io/old/packages oci://ghcr.io/new/packages

Charts are copied by tag, <repository>/<name>:<version>. Package trees are
pinned by digest only; their copy gets the tag tree-<first 16 hex digits>,
so nothing collects it, and is still pulled by digest.
"""
import sys

import yaml

index, old, new = sys.argv[1], sys.argv[2].removeprefix("oci://").rstrip("/"), sys.argv[3].removeprefix("oci://").rstrip("/")


def moved(location):
    rest = location.removeprefix("oci://")
    if rest == old or rest.startswith(old + "/"):
        return new + rest[len(old):]
    return None


pairs = set()
with open(index) as f:
    packages = (yaml.safe_load(f) or {}).get("packages") or {}
for package in packages.values():
    for version in package.get("versions") or []:
        spec = version.get("spec") or {}
        ref = (spec.get("sourceRef") or {}).get("url", "")
        if moved(ref):
            repo, digest = ref.removeprefix("oci://").split("@", 1)
            pairs.add((f"{repo}@{digest}", f"{moved(repo)}:tree-{digest.split(':', 1)[1][:16]}"))
        for variant in spec.get("variants") or []:
            for component in variant.get("components") or []:
                chart = component.get("chart") or {}
                to = moved(chart.get("repository", ""))
                if to:
                    tag = str(chart["version"]).replace("+", "_")
                    src = chart["repository"].removeprefix("oci://")
                    pairs.add((f"{src}/{chart['name']}:{tag}", f"{to}/{chart['name']}:{tag}"))
for src, dst in sorted(pairs):
    print(src, dst)
