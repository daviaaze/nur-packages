{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "orca";
  version = "1.4.173";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-0i3MzkvDnLcz5f4gM7wC21lhjxmgj0xYQzs9j6xMHlYFSmJ547s=";
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # Extra runtime dependencies that the AppImage needs.
  # orca uses Electron with node-pty (terminal), WebGL rendering, and secrets.
  extraPkgs = pkgs: with pkgs; [
    libsecret
    xorg.libXrandr
    libGL
    vulkan-loader
    nspr
    nss
    alsa-lib
  ];

  extraInstallCommands = ''
    # Install the .desktop file with corrected Exec path
    install -Dm444 ${appimageContents}/orca-ide.desktop $out/share/applications/orca.desktop
    substituteInPlace $out/share/applications/orca.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=orca %U'

    # Install all icon sizes
    for icon in ${appimageContents}/usr/share/icons/hicolor/*/apps/orca-ide.png; do
      size=$(echo "$icon" | sed 's|.*/hicolor/\(.*\)/apps/.*|\1|')
      install -Dm444 "$icon" "$out/share/icons/hicolor/$size/apps/orca.png"
    done
  '';

  meta = {
    description = "AI orchestrator — run Claude Code, Codex, OpenCode or Pi side-by-side, each in its own worktree";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    mainProgram = "orca";
    platforms = [ "x86_64-linux" ];
  };
}
