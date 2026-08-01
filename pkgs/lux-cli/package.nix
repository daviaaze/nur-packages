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
  src,
}:
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
