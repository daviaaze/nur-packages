{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  makeWrapper,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "orca";
  version = "1.4.163";

  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    tag = "v${finalAttrs.version}";
    hash = "sha256-EKwnw10YhRkVVZJv0IO963c8hs0KqWtFpbQ9bF77ErM=";
  };

  pnpmDeps = fetchPnpmDeps {
    pname = "orca";
    inherit (finalAttrs) version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-6SV2MB/EOrrSOjSSIDRLPcSGnwkAG2lNldAG3iE4zDg=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build:cli
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/orca
    cp -r package.json out node_modules $out/lib/orca
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/orca \
      --add-flags $out/lib/orca/out/cli/index.js
    runHook postInstall
  '';

  meta = {
    description = "AI orchestrator — run Claude Code, Codex, OpenCode or Pi side-by-side, each in its own worktree";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    mainProgram = "orca";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
})
