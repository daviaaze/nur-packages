{
  pkgs ? import <nixpkgs> { },
}:
let
  torrentio-addon = pkgs.callPackage ./pkgs/torrentio/package.nix { };

  # Private INTERNAL repo; only available locally (SSH), not in CI.
  lux-cli-src = builtins.tryEval (
    builtins.fetchGit {
      url = "git@github.com:lux-group/cli.git";
      ref = "main";
    }
  );
in
{
  atlassian-cli = pkgs.callPackage ./pkgs/atlassian-cli/package.nix { };
  batteryscope = pkgs.callPackage ./pkgs/batteryscope/package.nix { };
  opencli = pkgs.callPackage ./pkgs/opencli/package.nix { };
  orca = pkgs.callPackage ./pkgs/orca/package.nix { };
  pup = pkgs.callPackage ./pkgs/pup/package.nix { };
  rtk = pkgs.callPackage ./pkgs/rtk/package.nix { };
  torrentio-docker = pkgs.callPackage ./pkgs/torrentio/docker.nix {
    inherit torrentio-addon;
  };
  inherit torrentio-addon;
}
// pkgs.lib.optionalAttrs lux-cli-src.success {
  lux-cli = pkgs.callPackage ./pkgs/lux-cli/package.nix { src = lux-cli-src.value; };
}