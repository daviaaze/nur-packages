# Zen Browser — privacy-focused Firefox fork, shipped as a prebuilt binary
# tarball from GitHub releases (no source build).
#
# The unpacked tarball gets autopatchelf'd (RPATH for dlopen'd libs), then
# wrapped with wrapFirefox for desktop integration (WM class, update policy).
# The wrapped result is the `zen-browser` package; the raw build lives in
# passthru.unwrapped.
#
# Updater: scripts/update-package.sh zen-browser (custom case — this is a
# release asset, not a nixpkgs source tarball, so nix-update can't rewrite
# the embedded fetchurl hash).
{
  lib,
  fetchurl,
  stdenv,
  autoPatchelfHook,
  wrapGAppsHook3,
  patchelfUnstable,
  gtk3,
  adwaita-icon-theme,
  alsa-lib,
  dbus-glib,
  libxtst,
  libva,
  pipewire,
  wrapFirefox,
}:
let
  version = "1.22.2b";
  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-x86_64.tar.xz";
    hash = "sha256-Fjgjz1awaOgbuKSNk8nb2jmT9U8D+NN+aE44C/wRuJI=";
  };

  zen-unwrapped = stdenv.mkDerivation {
    pname = "zen-browser-unwrapped";
    inherit version src;

    nativeBuildInputs = [
      autoPatchelfHook
      wrapGAppsHook3
      patchelfUnstable
    ];

    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libxtst
      stdenv.cc.cc
    ];

    # Libraries that are dlopen'd at runtime — added to rpath
    # so the binaries can find them without LD_LIBRARY_PATH pollution
    runtimeDependencies = [ libva.out ];
    appendRunpaths = [ "${pipewire}/lib" ];

    # Mozilla uses "relrhack" for manual relocation processing
    patchelfFlags = [ "--no-clobber-old-sections" ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/zen-${version} $out/bin
      cp -r * $out/lib/zen-${version}/
      ln -s $out/lib/zen-${version}/zen $out/bin/zen

      runHook postInstall
    '';

    passthru = {
      applicationName = "Zen Browser";
      binaryName = "zen";
      libName = "zen-${version}";
      gtk3 = gtk3;
      ffmpegSupport = true;
      gssSupport = true;
      pipewireSupport = true;
    };

    meta = with lib; {
      description = "Zen Browser, a privacy-focused web browser built on Firefox";
      homepage = "https://zen-browser.app";
      license = licenses.mpl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = "zen";
    };
  };
in
wrapFirefox zen-unwrapped {
  pname = "zen-browser";
  applicationName = "zen";
  libName = "zen-${version}";
  wmClass = "zen-alpha";
  extraPolicies = {
    DisableAppUpdate = true;
  };
}
