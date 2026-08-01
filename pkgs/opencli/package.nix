{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  pkgs,
  makeWrapper,
}:
buildNpmPackage rec {
  pname = "opencli";
  version = "1.8.3";

  src = fetchFromGitHub {
    owner = "jackwener";
    repo = "OpenCLI";
    rev = "v${version}";
    hash = "sha256-aOL8hxIm3N8H8grS0SK0l0Ld7vIVrGTcGcOizjHW5Zg=";
  };

  npmDepsHash = "sha256-eFH5lH1kEpyGnfgbjU9Yui1t1YfYYE7RlMERIV19BXo=";

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
