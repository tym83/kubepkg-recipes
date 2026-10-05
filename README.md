# kubepkg recipes

Recipes for [kubepkg](https://github.com/tym83/kubepkg) packages. A recipe is to a kubepkg package what a `debian/` directory is to a Debian package: it pins the upstream sources, says how to build charts of them, and carries the package metadata.

Start a recipe with `kubepkg init` and check it with `kubepkg validate`, which pull requests also run. Every push to `main` builds the recipes, publishes the packages to `ghcr.io/tym83/kubepkg-packages` and the index to GitHub Pages. Published versions never change: to change a published package, raise `build` in its recipe.

```bash
curl -fsSLO https://raw.githubusercontent.com/tym83/kubepkg-recipes/main/keys/index.pub
kubepkg repo add main https://tym83.github.io/kubepkg-recipes/index.yaml --public-key index.pub
kubepkg install virtualization
```

The index is signed; `keys/index.pub` is the key to trust. A cluster refuses an index without a valid signature, and an index older than one it accepted.

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
