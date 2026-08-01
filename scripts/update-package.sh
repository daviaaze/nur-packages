#!/usr/bin/env bash
# Update a package in this flake to its latest upstream release.
#
# Usage: scripts/update-package.sh <attr> [--version <ver>]
#
# Packages are grouped by how their version is sourced:
#   nix-update   — version comes from GitHub releases, nix-update handles
#                  all hash types (src, npmDepsHash, pnpmDeps, cargoHash, ...)
#   custom       — needs bespoke handling (per-platform hashes, rev-based pins)
set -euo pipefail

ATTR="${1:?usage: update-package.sh <attr> [--version <ver>]}"
shift || true

LATEST=""
if [[ "${1:-}" == "--version" ]]; then
  LATEST="${2:?--version requires a value}"
  shift 2 || true
fi

# Map attr -> GitHub repo for release discovery
repo_for() {
  case "$1" in
    rtk) echo "rtk-ai/rtk" ;;
    pup) echo "datadog-labs/pup" ;;
    orca) echo "stablyai/orca" ;;
    opencli) echo "jackwener/OpenCLI" ;;
    atlassian-cli) echo "open-cli-collective/atlassian-cli" ;;
    batteryscope) echo "ptcodes/BatteryScope" ;;
    *) return 1 ;;
  esac
}

# Strip a leading "v" / "jtk-v" / "v0.0.x" noise from a tag for versioning
normalize_tag() {
  sed -E 's/^jtk-//; s/^v//'
}

if [[ -z "$LATEST" ]]; then
  REPO="$(repo_for "$ATTR")"
  if [[ -n "$REPO" ]]; then
    LATEST="$(gh release view --repo "$REPO" --json tagName --jq .tagName | normalize_tag)"
  fi
fi

echo "::group::$ATTR"
echo "Updating $ATTR -> ${LATEST:-<unchanged>}"

case "$ATTR" in
  # nix-update handles these: bumps version and all hashes, builds to verify
  rtk | orca | opencli)
    if [[ -n "$LATEST" ]]; then
      nix-update "$ATTR" --flake --version "$LATEST" --build
    else
      echo "No release found for $ATTR; skipping"
    fi
    ;;

  # pup: per-platform hash map — nix-update only knows how to rewrite a single
  # hash, so we update version + the Linux x86_64 hash manually.
  pup)
    if [[ -n "$LATEST" ]]; then
      PKG="pkgs/pup/package.nix"
      URL="https://github.com/datadog-labs/pup/releases/download/v${LATEST}/pup_${LATEST}_Linux_x86_64.tar.gz"
      NEW_HASH="$(nix store prefetch-file --json --hash-type sha256 "$URL" | jq -r .hash)"
      sed -i "s/version = \"[^\"]*\"/version = \"$LATEST\"/" "$PKG"
      sed -i "s|Linux_x86_64 = \"sha256-[^\"]*\"|Linux_x86_64 = \"$NEW_HASH\"|" "$PKG"
      echo "pup -> $LATEST ($NEW_HASH)"
    fi
    ;;

  # rev-based pins without GitHub releases — keep pinned, just report.
  atlassian-cli | batteryscope | torrentio-addon | torrentio-docker)
    echo "Rev-pinned package; not auto-updated. Bump rev/version manually."
    ;;

  *)
    echo "Unknown attr: $ATTR" >&2
    exit 1
    ;;
esac

echo "::endgroup::"
