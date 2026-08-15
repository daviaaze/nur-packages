{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  git,
  python3,
  makeWrapper,
  fetchPnpmDeps,
  pnpmConfigHook,
}:

let
  version = "0.1.0-rc.5";
  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    rev = "47f943859bef60e4160492346772ded9b24f765a";
    hash = "sha256-ZPGCNoPXVjP76Tm/tFPDX2X95cd83M4iHLmVP5dR+Ps=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh";
  inherit version src;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-aySHq0ywTMM5q7YuGHZrV3yQE3bwppgGfWH3wRnHCXk=";
    fetcherVersion = 4; # pnpm 11 store dump (SQLite); required for pnpm_11
  };

  nativeBuildInputs = [
    nodejs # node-gyp (koffi, node-pty) + esbuild (via vite build)
    pnpm # dsh plugin management forwards to pnpm (on PATH)
    git # pnpm clones git-hosted plugins' 'prepare'/'build'
    python3 # node-gyp needs a python for some addons
    makeWrapper
    pnpmConfigHook
  ];

  buildPhase = ''
    pnpm config set --location=project --reporter-hide-prefix 2>/dev/null || true
    pnpm run build # workspace tsdown (apps/cli → lib/bin.js) + vite (apps/web → dist)
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # Ship the whole built workspace at $out/lib, retaining pnpm's workspace
    # symlinks (cp -a keeps symlinks, so node_modules/@deepseek-ai/* still point
    # at ../../(packages|apps|...)/... inside $out/lib). This is much cheaper
    # than dereferencing the entire pnpm store and keeps relative resolution:
    #   bin.js            → $out/lib/apps/cli/lib/bin.js
    #   config/agent-pres → $out/lib/apps/cli/config/agent-presets
    #   external deps     → $out/lib/node_modules
    cp -a . $out/lib/
    rm -rf $out/lib/.git $out/lib/result

    # npm ships @deepseek-ai/* flat under the top-level node_modules; pnpm keeps
    # it nested, so the bundled loader's `import '@deepseek-ai/…'` fails to
    # resolve from arbitrary modules. Point the root @deepseek-ai cell at pnpm's
    # flat virtual-store cell (the superset of every workspace package), so any
    # runtime import resolves from any package — mirroring the npm layout.
    rm -rf $out/lib/node_modules/@deepseek-ai
    ln -s .pnpm/node_modules/@deepseek-ai \
      $out/lib/node_modules/@deepseek-ai

    # node-pty@1.1.0 ships prebuilds only for darwin/win32; on linux-x64 its
    # native pty.node must be compiled from source. nodejs bundles node-gyp at
    # lib/node_modules/npm/bin/node-gyp-bin (not on PATH), so prepend it;
    # python3 (node-gyp) and stdenv's gcc/make are on PATH.
    NP=$(cd "$out/lib/node_modules/.pnpm"/node-pty@*/node_modules/node-pty 2>/dev/null && pwd || true)
    if [ -n "$NP" ]; then
      (
        set -e
        cd "$NP"
        export PATH="${nodejs}/lib/node_modules/npm/bin/node-gyp-bin:$PATH"
        node-gyp rebuild
        test -f build/Release/pty.node || { echo "node-pty build: missing build/Release/pty.node" >&2; exit 1; }
      )
    fi

    makeWrapper ${nodejs}/bin/node $out/bin/dsh \
      --add-flags "--expose-internals $out/lib/apps/cli/lib/bin.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          pnpm
          git
          python3
        ]
      }

    runHook postInstall
  '';

  meta = with lib; {
    description = "DeepSeek Harness CLI (dsh): profile boot, plugin management, web UI alias";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = licenses.mit;
    mainProgram = "dsh";
    platforms = platforms.linux;
    maintainers = [ ];
    sourceProvenance = with sourceTypes; [ fromSource ];
  };
})
