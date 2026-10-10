#!/usr/bin/env python3
"""Fails unless every chart and package tree an index points to can be
pulled anonymously, as clusters pull them. A registry may create packages
private; an index pointing at those would break every cluster using it.

    check-public.py index.yaml
"""
import json
import sys
import urllib.error
import urllib.request

import yaml

ACCEPT = ",".join([
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


def refs(index):
    for package in (index.get("packages") or {}).values():
        for version in package.get("versions") or []:
            spec = version.get("spec") or {}
            url = (spec.get("sourceRef") or {}).get("url", "")
            if url.startswith("oci://"):
                repo, digest = url.removeprefix("oci://").split("@", 1)
                yield repo, digest
            for variant in spec.get("variants") or []:
                for component in variant.get("components") or []:
                    chart = component.get("chart") or {}
                    if chart.get("repository", "").startswith("oci://"):
                        yield chart["repository"].removeprefix("oci://") + "/" + chart["name"], str(chart["version"]).replace("+", "_")


def pullable(repo, reference):
    host, path = repo.split("/", 1)
    headers = {"Accept": ACCEPT}
    if host == "ghcr.io":
        with urllib.request.urlopen(f"https://ghcr.io/token?scope=repository:{path}:pull") as r:
            headers["Authorization"] = "Bearer " + json.load(r)["token"]
    req = urllib.request.Request(f"https://{host}/v2/{path}/manifests/{reference}", headers=headers, method="HEAD")
    try:
        with urllib.request.urlopen(req):
            return True
    except urllib.error.HTTPError:
        return False


with open(sys.argv[1]) as f:
    index = yaml.safe_load(f)
seen, private = set(), []
for repo, reference in refs(index):
    if (repo, reference) in seen:
        continue
    seen.add((repo, reference))
    if not pullable(repo, reference):
        private.append(f"{repo}:{reference}")
packages = sorted({p.rsplit(":", 1)[0] for p in private})
if private:
    print(f"{len(private)} of {len(seen)} artifacts cannot be pulled anonymously, in {len(packages)} packages; make them public:")
    print("\n".join(packages))
    sys.exit(1)
print(f"all {len(seen)} artifacts can be pulled anonymously")
