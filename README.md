# kubepkg recipes

Recipes for [kubepkg](https://github.com/tym83/kubepkg) packages. A recipe is to a kubepkg package what a `debian/` directory is to a Debian package: it pins the upstream sources, says how to build charts of them, and carries the package metadata.

Every push to `main` builds the recipes, publishes the packages to `ghcr.io/tym83/kubepkg-packages` and the index to GitHub Pages. Published versions never change: to change a published package, raise `build` in its recipe.

```bash
kubepkg repo add main https://tym83.github.io/kubepkg-recipes/index.yaml
kubepkg install kubevirt
```

| Package | Version | Built from |
|---|---|---|
| cert-manager | 1.21.2 | upstream chart |
| metrics-server | 0.9.0 | upstream chart |
| kube-state-metrics | 2.20.0 | upstream chart |
| cdi | 1.66.1 | release manifests, plus a chart for the CDI resource |
| kubevirt | 1.9.0 | release manifests, plus a chart for the KubeVirt resource |

Build locally with `scripts/build-all.sh`; see the script for publishing.

Licensed under the [Apache License 2.0](LICENSE).
