{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  glib,
  gtk4,
  libadwaita,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "batteryscope";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ptcodes";
    repo = "BatteryScope";
    rev = "787ddd59db357c719346922210a9f49b9e18de7b";
    hash = "sha256-upYGnmzkeQQmVWlfGHOBGkB6Rl0htAo+xWDAS4sEA9Q=";
  };

  cargoHash = "sha256-3A5vKDlviRhkpQgKZHmQmTcO1x/c5npW/CbccAZRv74=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    glib
    gtk4
    libadwaita
    sqlite
  ];

  # The logger script uses the sqlite3 CLI at runtime; wrap it into PATH
  # so the systemd service finds it regardless of user environment.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ sqlite ]}
    )
  '';

  postInstall = ''
    # Install icon (the app also does this at runtime, but we provide it
    # via the Nix store for proper desktop integration).
    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp icons/io.github.batteryscope.svg \
      $out/share/icons/hicolor/scalable/apps/

    # Desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/io.github.batteryscope.desktop << EOF
    [Desktop Entry]
    Name=BatteryScope
    Comment=Monitor laptop battery health and usage patterns
    Exec=$out/bin/BatteryScope
    Icon=io.github.batteryscope
    Terminal=false
    Type=Application
    Categories=System;Monitor;GTK;
    EOF
  '';

  meta = with lib; {
    description = "GTK4/libadwaita app to monitor laptop battery health, usage patterns, and long-term degradation trends";
    longDescription = ''
      A GTK4/libadwaita desktop application for Linux that monitors laptop
      battery health, usage patterns, and long-term degradation trends.
      Unlike a one-shot query (upower -d), BatteryScope continuously collects
      data over time via a systemd timer that logs per-minute battery stats
      to a local SQLite database (~/.local/share/battery-logger.db).

      Features:
      - Real-time power draw chart (last 2 minutes)
      - Capacity history chart (last 2 hours)
      - Estimated time remaining based on 15-minute rolling average
      - Health tracking with degradation rate and projected end-of-life
      - Temperature, voltage, current draw, and cycle count monitoring
    '';
    homepage = "https://github.com/ptcodes/BatteryScope";
    license = licenses.mit;
    mainProgram = "BatteryScope";
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
