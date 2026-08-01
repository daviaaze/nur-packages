{
  lib,
  appimageTools,
  fetchurl,
}:
let
  version = "1.4.163";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-OWphybstsEMdTSOqqKUcR2+HW1mxWQYj2JFPsnpVIEk=";
  };

  appimageContents = appimageTools.extract {
    pname = "orca";
    inherit version src;
  };
in
appimageTools.wrapType2 {
  pname = "orca";
  inherit version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/orca-ide.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=orca %U'
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/orca-ide.png \
      -t $out/share/icons/hicolor/512x512/apps
  '';

  meta = {
    description = "AI orchestrator — run Claude Code, Codex, OpenCode or Pi side-by-side, each in its own worktree";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    mainProgram = "orca";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
