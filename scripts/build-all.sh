#!/usr/bin/env bash
# Builds every recipe under recipes/. With REGISTRY set, publishes the
# packages there and writes the repository index, merged into the index
# published before (BASE_INDEX), so published versions are kept and never
# change.
#
#   REGISTRY     oci://... to publish to; unset builds without publishing
#   BASE_INDEX   URL or file of the published index
#   OUT          where index.yaml goes (default: _site)
#   KUBEPKG      kubepkg binary (default: kubepkg on PATH)
#   KUBEPKG_FLAGS  extra flags for build and index, e.g. --plain-http
set -euo pipefail

cd "$(dirname "$0")/.."
KUBEPKG=${KUBEPKG:-kubepkg}
OUT=${OUT:-_site}
read -r -a FLAGS <<< "${KUBEPKG_FLAGS:-}"
DIST=$(mktemp -d)
trap 'rm -rf "${DIST}"' EXIT

for recipe in recipes/*/; do
  echo "== ${recipe}"
  if [[ -n "${REGISTRY:-}" ]]; then
    "${KUBEPKG}" build "${recipe}" --registry "${REGISTRY}" -o "${DIST}" ${FLAGS[@]+"${FLAGS[@]}"}
  else
    "${KUBEPKG}" build "${recipe}" ${FLAGS[@]+"${FLAGS[@]}"}
  fi
done

if [[ -n "${REGISTRY:-}" ]]; then
  mkdir -p "${OUT}"
  merge=()
  [[ -n "${BASE_INDEX:-}" ]] && merge=(--merge "${BASE_INDEX}")
  "${KUBEPKG}" repo index "${DIST}" ${merge[@]+"${merge[@]}"} -o "${OUT}/index.yaml" ${FLAGS[@]+"${FLAGS[@]}"}
fi
