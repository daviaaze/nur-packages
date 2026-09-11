# stremio-libtorrent-server — patched build
#
# Fixes the FileNotFoundError-after-restart bug where a file that exists in the
# torrent metadata (and on disk) can't be opened after a crash/restart because
# libtorrent restores file priorities from resume data and doesn't recreate
# zero-priority files until a re-check runs.
#
# Patch: force a re-check and wait for the file to appear before streaming.
{
  lib,
  fetchFromGitHub,
  buildPythonPackage,
  python,
  uv-build,
  srcPath ? null,
}:
let
  pname = "stremiosrv";
  version = "1.3.4";
in
buildPythonPackage {
  inherit pname version;

  src = if srcPath != null then
    srcPath
  else
    fetchFromGitHub {
      owner = "daviaaze";
      repo = "stremio-libtorrent-server";
      rev = "f517167c1c45d28234cef28de1e1d5beb0f80fde";
      hash = "sha256-mZPbiRXnD/ZUqN+NHCbXx4R1QthF7px80pq/9HtlApY=";
    };

  pyproject = true;

  # Sequential episode prioritization: while watching episode N of a season
  # pack, file priorities give N max priority and the next episodes a
  # descending ladder (3,2,1) so the follow-up episode is pre-downloaded
  # without racing the current one. Anterior episodes stay skipped (prio 0).
  # (Applied in fork, no Nix-side patch needed)

  # Remove the PyPI libtorrent dependency — we use nixpkgs' libtorrent-rasterbar
  # which provides the same `libtorrent` Python module.
  postPatch = ''
    sed -i "/libtorrent/d" pyproject.toml
  '';

  build-system = [ uv-build ];

  dependencies = [
    python.pkgs.fastapi
    python.pkgs.pydantic
    python.pkgs.pydantic-settings
    python.pkgs.uvicorn
    python.pkgs.charset-normalizer
    python.pkgs.libtorrent-rasterbar
  ];

  pythonImportsCheck = [
    "stremiosrv"
    "stremiosrv.app"
    "stremiosrv.torrent.engine"
    "stremiosrv.stream.fileserver"
    "stremiosrv.api.playback"
  ];

  meta = {
    description = "Open, self-hosted Stremio streaming server (libtorrent engine + bundled web player) — patched for FileNotFoundError recovery";
    homepage = "https://github.com/andrewhack/stremio-libtorrent-server";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
