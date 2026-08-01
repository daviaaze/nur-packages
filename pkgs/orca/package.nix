{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
}:
buildNpmPackage rec {
  pname = "orca";
  version = "1.4.163";

  src = fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    tag = "v${version}";
    hash = "sha256-EKwnw10YhRkVVZJv0IO963c8hs0KqWtFpbQ9bF77ErM=";
  };

  npmDepsHash = "sha256-UAS9cTUQuqYkD96pnX/+zdqrYGqF2gnlNQVlpwn/V0I=";

  nodejs = nodejs_24;

  postBuild = ''
    npm run build:cli
  '';

  postInstall = ''
    # Ship the CLI output plus its runtime deps.
    mkdir -p $out/lib/orca
    cp -r package.json out node_modules $out/lib/orca
    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/orca \
      --add-flags $out/lib/orca/out/cli/index.js
  '';

  meta = {
    description = "AI orchestrator — run Claude Code, Codex, OpenCode or Pi side-by-side, each in its own worktree";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    mainProgram = "orca";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
