{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pkgs,
  makeWrapper,
}:
buildNpmPackage rec {
  pname = "opencli";
  version = "1.8.8";

  src = fetchFromGitHub {
    owner = "jackwener";
    repo = "OpenCLI";
    rev = "v${version}";
    hash = "sha256-PRuQklTX8vejqFU6m0jhkApqOKDwAMKkncRHeTG+JC0=";
  };

  npmDepsHash = "sha256-yIZV7KOg4oblvFU8Aq/ijGCGC4eCe6t+sAg2XL4moGQ=";

  # Skip auto-generated install hooks - we handle build ourselves
  dontNpmInstall = true;

  buildPhase = ''
    runHook preBuild
    npm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@jackwener/opencli
    cp -r dist node_modules package.json $out/lib/node_modules/@jackwener/opencli/
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/opencli \
      --add-flags "$out/lib/node_modules/@jackwener/opencli/dist/src/main.js"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Make any website or Electron App your CLI — AI-powered browser automation";
    longDescription = ''
      OpenCLI turns any website or Electron app into a command-line interface.
      100+ built-in site adapters. Browser-based automation via Chrome DevTools
      Protocol. Built for AI agents to discover, learn, and execute tools.
    '';
    homepage = "https://github.com/jackwener/opencli";
    license = licenses.asl20;
    mainProgram = "opencli";
    platforms = platforms.all;
    maintainers = [ ];
  };
}
