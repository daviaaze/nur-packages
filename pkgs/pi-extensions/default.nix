{
  lib,
  stdenv,
  fetchFromGitHub,
  symlinkJoin,
}:

let
  manifest = builtins.fromJSON (builtins.readFile ./plugins.json);
  inherit (manifest) extDir;

  # Strip the repo-relative extensions dir prefix, keeping any nested
  # subpath (e.g. pi-setup/extensions/custom-docs/index.ts → custom-docs/index.ts).
  rel = f: lib.removePrefix "${extDir}/" f;

  mkPiExtension =
    name: cfg:
    stdenv.mkDerivation {
      pname = "pi-extension-${name}";
      version = if cfg.src ? rev then builtins.substring 0 8 cfg.src.rev else "local";

      src =
        if cfg.src.type == "github" then
          fetchFromGitHub {
            inherit (cfg.src)
              owner
              repo
              rev
              hash
              ;
          }
        else
          throw "pi-extension[${name}]: unsupported src.type '${cfg.src.type}'";

      # Extension file(s) are copied verbatim into $out/extensions; no build step.
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        ${lib.concatMapStringsSep "\n" (f: ''
          mkdir -p "$out/extensions/$(dirname "${rel f}")"
          cp "$src/${f}" "$out/extensions/${rel f}"
        '') cfg.files}
        runHook postInstall
      '';

      meta = with lib; {
        description = "Pi extension: ${name}";
        homepage = "https://github.com/daviaaze/ai-workspace";
        license = licenses.mit;
        platforms = platforms.linux;
      };
    };

  extensions = lib.mapAttrs' (
    name: cfg: lib.nameValuePair name (mkPiExtension name cfg)
  ) manifest.plugins;
in
extensions
// {
  # All extensions joined for the module / a single `nix build`.
  default = symlinkJoin {
    name = "pi-extensions-all";
    paths = lib.attrValues extensions;
  };
}
