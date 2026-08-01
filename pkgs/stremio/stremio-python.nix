{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  python314,
  python3,
}:
let
  # stremio-server requires pydantic-settings>=2.14.1; upstream has older.
  # NOTE: this is a SEPARATE interpreter attribute — it does not mutate
  # python3/python314, so the system python package set stays bit-identical
  # to cache.nixos.org. (Overriding python314 or pythonPackagesExtensions
  # previously changed hashes across the whole reverse-dependency cone:
  # inline-snapshot -> pydantic -> yarl -> aiohttp -> fsspec -> torch,
  # forcing 2h+ source builds.)
  #
  # python3.14 is the default python3, so all other deps
  # (fastapi, uvicorn, libtorrent-rasterbar, ...) come from cache.
  stremioPython = python314.override {
    packageOverrides = python-final: python-prev: {
      pydantic-settings = python-prev.pydantic-settings.overridePythonAttrs (old: {
        version = "2.14.1";
        src = fetchFromGitHub {
          owner = "pydantic";
          repo = "pydantic-settings";
          tag = "v2.14.1";
          hash = "sha256-COft7a0yQFC+dhEog1QKtMmBUjqqm494y/fFp+Y2xBw=";
        };
      });
      # fastapi's checkInputs include pydantic-settings, so the bump above
      # forces a local fastapi rebuild in this scope. Skip its pytest suite
      # (build-only, ~30s instead of minutes); upstream tests still ran on
      # Hydra for the cached fastapi used by the system python set.
      fastapi = python-prev.fastapi.overridePythonAttrs (_: {
        doCheck = false;
      });
    };
  };
in
stremioPython
