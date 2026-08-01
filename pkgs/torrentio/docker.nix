# torrentio-addon Docker image — minimal Node 22 image with the torrentio addon.
#
# Runtime: listens on PORT (default 7000). Needs REDIS_URL at startup
# (rate limiter connects eagerly) and DATABASE_URI (torrent index, read-only).
{
  lib,
  dockerTools,
  nodejs_22,
  runCommand,
  cacert,
  torrentio-addon,
}:
let
  # Assemble /app from the packaged addon. Dereference the node_modules symlink
  # so it's real inside the image (store symlinks would dangle in the container).
  appDir = runCommand "torrentio-appdir" { } ''
    mkdir -p $out/app
    cp -rL ${torrentio-addon}/. $out/app/
    chmod -R u+w $out/app
  '';
in
dockerTools.buildImage {
  name = "torrentio-addon";
  tag = "latest";

  copyToRoot = [
    nodejs_22
    cacert
    appDir
  ];

  config = {
    Env = [
      "PATH=/bin"
      "PORT=7000"
      "NODE_ENV=production"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/app";
    ExposedPorts = {
      "7000/tcp" = { };
    };
    Entrypoint = [ "/bin/node" ];
    # Matches upstream Dockerfile: insecure HTTP parser for debrid/moch responses.
    Cmd = [ "--insecure-http-parser" "index.js" ];
    HealthCheck = {
      Test = [ "CMD" "/bin/node" "-e" "fetch('http://127.0.0.1:7000/').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))" ];
      Interval = 30000000000;
      Timeout = 5000000000;
      StartPeriod = 30000000000;
      Retries = 3;
    };
  };
}
