{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
}:
let
  version = "1.11.0";
  platform =
    if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
      "Linux_x86_64"
    else if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64 then
      "Linux_arm64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64 then
      "Darwin_x86_64"
    else if stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 then
      "Darwin_arm64"
    else
      throw "Unsupported platform: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation {
  pname = "pup";
  inherit version;

  src = fetchurl {
    url = "https://github.com/datadog-labs/pup/releases/download/v${version}/pup_${version}_${platform}.tar.gz";
    hash =
      {
        Linux_x86_64 = "sha256-9CExZ1idR9PAhD0jRMUSPmgAFJwq4oSw5a12X9pOlq4=";
        Linux_arm64 = lib.fakeSha256;
        Darwin_x86_64 = lib.fakeSha256;
        Darwin_arm64 = lib.fakeSha256;
      }
      .${platform};
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = [
    openssl
  ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 pup $out/bin/pup
  '';

  meta = with lib; {
    description = "Datadog CLI tool for querying observability data";
    homepage = "https://github.com/datadog-labs/pup";
    license = licenses.asl20;
    mainProgram = "pup";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
