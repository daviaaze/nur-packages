# torrentio-addon — daviaaze/torrentio-scraper (Stremio addon, homelab fork)
#
# Produces an assembled app root ($out) containing the addon source plus a
# Nix-built node_modules (production deps only, git deps resolved by npm).
# Layered into a Docker image by docker.nix.
#
# Source: our homelab branch of the fork — one real commit per feature
# (tracker env config, best trackers on all magnets, on-demand sync
# fallback, ...). Upstream sync = git rebase upstream/master, documented in
# the fork README.
{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs_22,
  stdenv,
  version ? "1.0.14",
  rev ? "2bf3e1975cdc4461836b2dbd6b156a00206d8c2a",
  hash ? "sha256-VAOiAhwKvCdziArb/nBV+2O/4C7qUGjmOirwoqwihQQ=",
  npmDepsHash ? "sha256-U9ee4xbx/dFO+Si00avfO4sm56kUj8aLgjAS6ADHk5Y=",
}:
let
  src = fetchFromGitHub {
    owner = "daviaaze";
    repo = "torrentio-scraper";
    inherit rev hash;
  };

  # node_modules built from the addon subdir's package-lock.json.
  nodeModules = buildNpmPackage {
    pname = "torrentio-addon-deps";
    inherit version;
    src = src;
    sourceRoot = "source/addon";
    inherit npmDepsHash;
    nodejs = nodejs_22;
    # v2 fetcher avoids a v1 npm cache-permission bug with the root-owned cache.
    npmDepsFetcherVersion = 2;
    # No build/compile step — this is a plain JS package. Skip the default
    # `npm run build` so the derivation just installs deps.
    dontNpmBuild = true;
    # Only ship production dependencies (matches the upstream `npm ci --only-production`).
    npmInstallFlags = [ "--omit=dev" ];
  };
in
# Assemble /app: addon source + node_modules, with a package.json that carries
# the name/version for `node index.js` (which is not used at runtime).
stdenv.mkDerivation {
  pname = "torrentio-addon";
  inherit version src;
  sourceRoot = "source/addon";
  dontBuild = true;
  dontConfigure = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    chmod -R u+w $out
    rm -f $out/node_modules
    # buildNpmPackage installs under lib/node_modules/<package-name>/node_modules
    ln -s ${nodeModules}/lib/node_modules/stremio-torrentio/node_modules $out/node_modules
    runHook postInstall
  '';
}
