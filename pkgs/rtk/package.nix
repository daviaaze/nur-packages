# RTK — CLI proxy that reduces LLM token consumption by 60-90%
#
# Intercepts common dev commands (git, ls, cat, test runners, docker, kubectl)
# before they reach the LLM context window. Compresses/filters output to
# essential information using strategy per command type.
#
# This package fetches the pre-built statically-linked musl binary from
# GitHub releases — no build toolchain required.
{
  lib,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "0.43.0";
  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-/4oed2ZJbhdSkaha7KHcl8n/bfM+UeWJPR+8eP6ipgk=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "rtk";
  inherit version;

  src = src;

  dontBuild = true;
  dontConfigure = true;

  # Single-file tarball: no directory created by unpacker
  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp rtk $out/bin/rtk
    chmod +x $out/bin/rtk
  '';

  meta = with lib; {
    description = "CLI proxy that reduces LLM token consumption by 60-90% on common dev commands";
    longDescription = ''
      RTK filters and compresses command outputs before they reach your LLM context.
      Single Rust binary, 100+ supported commands, <10ms overhead.

      Strategically rewrites common dev commands (git, ls, cat, test runners, docker,
      kubectl, aws, and more) to produce compact output while preserving all essential
      information. Designed for AI coding agents like Claude Code, Copilot, Gemini CLI,
      and Pi.
    '';
    homepage = "https://github.com/rtk-ai/rtk";
    changelog = "https://github.com/rtk-ai/rtk/releases/tag/v${version}";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = [ ];
    mainProgram = "rtk";
  };
}
