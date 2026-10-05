# kubepkg recipes

Recipes for [kubepkg](https://github.com/tym83/kubepkg) packages. A recipe is to a kubepkg package what a `debian/` directory is to a Debian package: it pins the upstream sources, says how to build charts of them, and carries the package metadata.

Every push to `main` builds the recipes, publishes the packages to `ghcr.io/tym83/kubepkg-packages` and the index to GitHub Pages. Published versions never change: to change a published package, raise `build` in its recipe.

```bash
kubepkg repo add main https://tym83.github.io/kubepkg-recipes/index.yaml
kubepkg install virtualization
```

Every package is a set of ordinary Helm charts in `ghcr.io/tym83/kubepkg-packages/<package>/<chart>`, versioned `<version>-<build>`, so Helm, Flux, Argo CD and werf install them without kubepkg; `kubepkg render` writes a resolved, ordered set for Flux, Argo CD or helmfile.

| Package | Version | Built from |
|---|---|---|
| cert-manager | 1.21.2 | upstream chart |
| metrics-server | 0.9.0 | upstream chart |
| kube-state-metrics | 2.20.0 | upstream chart |
| cdi | 1.66.1 | release manifests, plus a chart for the CDI resource |
| kubevirt | 1.9.0 | release manifests, plus a chart for the KubeVirt resource |
| virtualization | 1.0.0 | meta package: kubevirt ~1.9 and cdi ~1.66 |

Build locally with `scripts/build-all.sh`; see the script for publishing.

Licensed under the [Apache License 2.0](LICENSE).
