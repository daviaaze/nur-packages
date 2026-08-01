{
  lib,
  stdenv,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  yarnInstallHook,
  makeWrapper,
  nodejs,
  pulumi-bin,
  postgresql,
  ssm-session-manager-plugin,
  awscli2,
}:
let
  # Private INTERNAL repo — fetched via SSH, which works locally but
  # not in CI. This is fine: lux-cli is only built locally (never on
  # GitHub Actions). The repo is not a flake input to avoid forcing
  # CI to fetch a repo it cannot access.
  src = builtins.fetchGit {
    url = "git@github.com:lux-group/cli.git";
    ref = "main";
  };
in
stdenv.mkDerivation {
  pname = "luxuryescapes-cli";
  inherit ((builtins.fromJSON (builtins.readFile "${src}/package.json"))) version;

  inherit src;

  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-blg+WecvghZf7gdA9uMxwBX2vvVvT4427D8L0qyoyBc=";
  };

  nativeBuildInputs = [
    yarnConfigHook
    yarnBuildHook
    yarnInstallHook
    makeWrapper
    nodejs
  ];

  buildInputs = [
    postgresql
    ssm-session-manager-plugin
    awscli2
  ];

  preConfigure = ''
    export NPM_TOKEN=""
  '';

  postInstall = ''
    wrapProgram $out/bin/le \
      --prefix PATH : ${
        lib.makeBinPath [
          pulumi-bin
          ssm-session-manager-plugin
          awscli2
          postgresql
        ]
      }
  '';

  meta = with lib; {
    description = "LuxuryEscapes CLI tool";
    homepage = "https://github.com/luxuryescapes/cli";
    license = licenses.mit;
    maintainers = [ ];
  };
}