{
  pkgs ? import <nixpkgs> { },
}:
let
  torrentio-addon = pkgs.callPackage ./pkgs/torrentio/package.nix { };
in
{
  atlassian-cli = pkgs.callPackage ./pkgs/atlassian-cli/package.nix { };
  batteryscope = pkgs.callPackage ./pkgs/batteryscope/package.nix { };
  lux-cli = pkgs.callPackage ./pkgs/lux-cli/package.nix { };
  opencli = pkgs.callPackage ./pkgs/opencli/package.nix { };
  orca = pkgs.callPackage ./pkgs/orca/package.nix { };
  pup = pkgs.callPackage ./pkgs/pup/package.nix { };
  rtk = pkgs.callPackage ./pkgs/rtk/package.nix { };
  torrentio-docker = pkgs.callPackage ./pkgs/torrentio/docker.nix {
    inherit torrentio-addon;
  };
  inherit torrentio-addon;
}
