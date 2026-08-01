# NUR-style non-flake entry point:
#   nix-build -A orca
#   nix-env -iA nur.repos.daviaaze-style... (local: -f default.nix orca)
{
  pkgs ? import <nixpkgs> { },
  lux-cli-src ? null,
}:
{
  atlassian-cli = pkgs.callPackage ./pkgs/atlassian-cli/package.nix { };
  batteryscope = pkgs.callPackage ./pkgs/batteryscope/package.nix { };
  opencli = pkgs.callPackage ./pkgs/opencli/package.nix { };
  orca = pkgs.callPackage ./pkgs/orca/package.nix { };
  pup = pkgs.callPackage ./pkgs/pup/package.nix { };
  rtk = pkgs.callPackage ./pkgs/rtk/package.nix { };
}
// pkgs.lib.optionalAttrs (lux-cli-src != null) {
  lux-cli = pkgs.callPackage ./pkgs/lux-cli/package.nix { src = lux-cli-src; };
}
