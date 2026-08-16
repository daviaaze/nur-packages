{
  pkgs ? import <nixpkgs> { },
}:
let
  torrentio-addon = pkgs.callPackage ./pkgs/torrentio/package.nix { };
  stremio-python = pkgs.callPackage ./pkgs/stremio/stremio-python.nix { };
in
{
  atlassian-cli = pkgs.callPackage ./pkgs/atlassian-cli/package.nix { };
  batteryscope = pkgs.callPackage ./pkgs/batteryscope/package.nix { };
  dsh = pkgs.callPackage ./pkgs/dsh/package.nix { };
  pi-extensions = (pkgs.callPackage ./pkgs/pi-extensions/default.nix { }).default;
  pi-rtk = (pkgs.callPackage ./pkgs/pi-extensions/default.nix { }).rtk;
  opencli = pkgs.callPackage ./pkgs/opencli/package.nix { };
  orca = pkgs.callPackage ./pkgs/orca/package.nix { };
  pup = pkgs.callPackage ./pkgs/pup/package.nix { };
  rtk = pkgs.callPackage ./pkgs/rtk/package.nix { };
  torrentio-docker = pkgs.callPackage ./pkgs/torrentio/docker.nix {
    inherit torrentio-addon;
  };
  stremio-server = pkgs.callPackage ./pkgs/stremio/server.nix {
    inherit stremio-python;
  };
  stremio-docker = pkgs.callPackage ./pkgs/stremio/docker.nix {
    python = stremio-python;
    stremio-server = stremio-server;
    inherit stremio-python;
  };
  inherit torrentio-addon stremio-python;
}
