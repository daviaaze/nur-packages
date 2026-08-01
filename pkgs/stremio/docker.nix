# stremio-libtorrent-server Docker image — patched, built from scratch in Nix
#
# Replicates the original Dockerfile using Nix components:
#   - Python 3.14 + patched stremiosrv package
#   - ffmpeg (with VAAPI/NVENC support via jellyfin-ffmpeg)
#   - nginx (for TLS termination + web UI serving)
#   - curl (for healthcheck)
#
# This avoids depending on the proprietary androshack/stremio-docker-dual base.
{
  lib,
  dockerTools,
  stremio-server,
  ffmpeg,
  nginx,
  curl,
  python,
  runCommand,
  writeText,
  symlinkJoin,
  bash,
  coreutils,
  stdenvNoCC,
  web-ui ? ./web-ui,
}:
let
  # Build a proper Python environment with all deps using python.withPackages
  # This includes transitive dependencies automatically (starlette, pydantic-core, etc.)
  pythonEnv = python.withPackages (ps: [
    ps.fastapi
    ps.uvicorn
    ps.pydantic
    ps.pydantic-settings
    ps.charset-normalizer
    ps.libtorrent-rasterbar
  ]);

  # Create a venv-like environment combining the Python env + stremio-server
  appEnv = symlinkJoin {
    name = "stremio-app-env";
    paths = [
      stremio-server
      pythonEnv
    ];
    postBuild = ''
      # Link uvicorn and stremiosrv into a flat bin directory
      mkdir -p $out/bin
      if [ -e ${pythonEnv}/bin/uvicorn ]; then
        ln -sf ${pythonEnv}/bin/uvicorn $out/bin/uvicorn
      fi
      if [ -e ${stremio-server}/bin/stremiosrv ]; then
        ln -sf ${stremio-server}/bin/stremiosrv $out/bin/stremiosrv
      fi
    '';
  };

  # Collect all site-packages directories from the pythonEnv and stremio-server
  # This replicates what the stremiosrv wrapper does with site.addsitedir
  pythonPath = lib.concatStringsSep ":" [
    "${stremio-server}/lib/python3.14/site-packages"
    "${pythonEnv}/lib/python3.14/site-packages"
  ];

  # Web UI build files extracted from the upstream androshack/stremio-docker-dual image
  webUI = runCommand "stremio-web-ui" { } ''
    mkdir -p $out/srv/stremio-server/build
    cp -r ${./web-ui}/* $out/srv/stremio-server/build/
    # localStorage.json must be at the build root (service-worker.js expects it)
    cp ${./web-ui}/localStorage.json $out/srv/stremio-server/localStorage.json
    chmod -R +r $out/srv/stremio-server
  '';

  # Entrypoint script (replicates docker/entrypoint.sh)
  entrypointScript = writeText "stremio-entrypoint.sh" ''
#!/bin/sh
set -e

    # Generate default localStorage.json if not present
    if [ ! -f /root/.stremio-server/localStorage.json ]; then
      cp /srv/stremio-server/build/localStorage.json /root/.stremio-server/localStorage.json 2>/dev/null || true
    fi

    # Generate HTTPS server block if TLS cert is present
    if [ -f /root/.stremio-server/certificates.pem ]; then
      cat > /etc/nginx/stremio-https.conf << 'HTTPS'
server {
  listen 12470 ssl http2;
  ssl_certificate /root/.stremio-server/certificates.pem;
  ssl_certificate_key /root/.stremio-server/certificates.pem;

  location / {
    proxy_pass http://127.0.0.1:11470;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
  }
}
HTTPS
    else
      touch /etc/nginx/stremio-https.conf
    fi

    # Start nginx for web UI and API proxying
    nginx -c /etc/nginx/stremio.conf -g "pid /tmp/nginx.pid;"

    # Start the streaming server (stremiosrv.app:build_app is a factory)
    exec uvicorn stremiosrv.app:build_app --factory --host 0.0.0.0 --port 11470 --proxy-headers
  '';

  # nginx config: serve web UI on port 8080, proxy API to uvicorn on 11470
  nginxConf = writeText "stremio-nginx.conf" ''
    worker_processes 1;
    events { worker_connections 1024; }
    http {
      default_type application/octet-stream;

      types {
        text/html                             html htm shtml;
        text/css                              css;
        text/xml                              xml;
        image/gif                             gif;
        image/jpeg                            jpeg jpg;
        application/javascript                js;
        application/atom+xml                  atom;
        application/rss+xml                   rss;
        font/woff2                            woff2;
        application/wasm                      wasm;
        application/json                      json;
        image/png                             png;
        image/svg+xml                         svg svgz;
        image/webp                            webp;
        image/x-icon                          ico;
        text/vtt                              vtt;
        video/mp2t                            ts;
        application/vnd.apple.mpegurl         m3u8;
        text/xml                              xml;
      }

      access_log /dev/stdout;
      error_log /dev/stderr warn;

      # Compression
      gzip on;
      gzip_vary on;
      gzip_proxied any;
      gzip_http_version 1.1;
      gzip_comp_level 4;
      gzip_min_length 256;
      gzip_types
        application/json
        application/javascript
        application/xml
        application/vnd.apple.mpegurl
        text/css
        text/javascript
        text/plain
        text/vtt
        text/xml;

      # Proxy settings
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header Origin $http_origin;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_http_version 1.1;
      proxy_cache off;
      proxy_buffering off;
      proxy_max_temp_file_size 0;

      # Backend — stremiosrv uvicorn
      upstream backend {
        server 127.0.0.1:11470;
        keepalive 32;
      }

      # Main web UI server on port 8080
      server {
        listen 8080;
        server_name _;

        # API routes — proxy to uvicorn
        location ~ ^/(casting|local-addon|proxy|settings|create|removeAll|samples|probe|subtitlesTracks|opensubHash|subtitles|network-info|device-info|get-https|hwaccel-profiler|status|exec|stream|heartbeat|yt|tracks|intro) {
          proxy_pass http://backend;
        }

        location ~ ^/(hlsv2|rar|zip) {
          proxy_set_header Connection "keep-alive";
          keepalive_timeout 5 5;
          keepalive_requests 100;
          proxy_pass http://backend;
        }

        location ~ ^/([^/]+)/(stats\.json|create|remove|destroy|burn) {
          proxy_pass http://backend;
        }

        location ~ "^/([a-zA-Z0-9]{40})/([0-9]+)$" {
          proxy_pass http://backend;
        }

        location ~ ^/([^/]+)/([^/]+)/(stats\.json|hls\.m3u8|master\.m3u8|stream\.m3u8|dlna|thumb\.jpg) {
          proxy_pass http://backend;
        }

        location ~ ^/([^/]+)/([^/]+)/(stream-q-[^/]+\.m3u8|stream-[^/]+\.m3u8|subs-[^/]+\.m3u8|mp4stream-q-[^/]+\.m3u8|mp4stream-q-[^/]+/[^/]+\.mp4) {
          proxy_set_header Connection "keep-alive";
          keepalive_timeout 5 5;
          keepalive_requests 100;
          proxy_pass http://backend;
        }

        location ~ ^/([^/]+)/([^/]+)/(stream-q-[^/]+|stream-[^/]+)/[^/]+\.(ts|mp4) {
          proxy_set_header Connection "keep-alive";
          keepalive_timeout 5 5;
          keepalive_requests 100;
          proxy_pass http://backend;
        }

        location = /(thumb\.jpg|stats\.json) {
          proxy_pass http://backend;
        }

        # Health check endpoint
        location /health {
          proxy_pass http://backend;
        }

        # Web UI static files
        location /manifest.json {
          root /srv/stremio-server/build;
        }

        location / {
          root /srv/stremio-server/build;
          index index.html index.htm;
          try_files $uri $uri/ /index.html;

          location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2|env|wasm)$ {
            expires 7d;
            add_header Cache-Control "public, no-transform";
          }
        }
      }

      # HTTPS server block — generated by entrypoint if cert is present
      include /etc/nginx/stremio-https.conf;
    }
  '';
in
dockerTools.buildImage {
  name = "stremio-libtorrent-server";
  tag = "patched";

  copyToRoot = [
    appEnv
    webUI
    ffmpeg
    nginx
    curl
    bash
    coreutils
    (runCommand "stremio-root" { } ''
      mkdir -p $out/srv/app/docker
      mkdir -p $out/etc/nginx
      mkdir -p $out/tmp
      mkdir -p $out/root/.stremio-server
      cp ${entrypointScript} $out/srv/app/docker/entrypoint.sh
      chmod +x $out/srv/app/docker/entrypoint.sh
      cp ${nginxConf} $out/etc/nginx/stremio.conf
      # Create /bin/sh symlink for the entrypoint shebang
      mkdir -p $out/bin
      ln -s ${bash}/bin/bash $out/bin/sh
      # Create /usr/bin/env for scripts that use #!/usr/bin/env
      mkdir -p $out/usr/bin
      ln -s ${coreutils}/bin/env $out/usr/bin/env
      # Create /etc/passwd and /etc/group for nginx
      mkdir -p $out/etc
      echo 'root:x:0:0:root:/root:/bin/sh' > $out/etc/passwd
      echo 'nobody:x:65534:65534:nobody:/nonexistent:/bin/sh' >> $out/etc/passwd
      echo 'root:x:0:' > $out/etc/group
      echo 'nobody:x:65534:' >> $out/etc/group
      echo 'nogroup:x:65534:' >> $out/etc/group
      # Create /var/log/nginx for nginx error log
      mkdir -p $out/var/log/nginx
      # Create /var/cache/nginx for nginx cache
      mkdir -p $out/var/cache/nginx
    '')
  ];

  config = {
    Env = [
      "PATH=${pythonEnv}/bin:${appEnv}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      "PYTHONPATH=${pythonPath}"
      "STREMIOSRV_CACHE_ROOT=/root/.stremio-server"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
      "11470/tcp" = { };
      "12470/tcp" = { };
      "6881/tcp" = { };
      "6881/udp" = { };
    };
    Volumes = {
      "/root/.stremio-server" = { };
    };
    WorkingDir = "/srv/app";
    Entrypoint = [ "/srv/app/docker/entrypoint.sh" ];
    Cmd = [ ];

    HealthCheck = {
      Test = [ "CMD" "curl" "-fsS" "http://127.0.0.1:8080/" ];
      Interval = 30000000000; # 30s in nanoseconds
      Timeout = 5000000000;  # 5s
      StartPeriod = 20000000000; # 20s
      Retries = 3;
    };
  };
}