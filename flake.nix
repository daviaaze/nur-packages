{
  description = "daviaaze's NUR-style package collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      mkPackages =
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          torrentio-addon = pkgs.callPackage ./pkgs/torrentio/package.nix { };

          # Private INTERNAL repo; fetched via SSH. In CI (pure eval mode),
          # builtins.fetchGit fails, so we gate it with tryEval. This means
          # lux-cli is absent from the packages attrset in CI — only built locally.
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
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          packages = mkPackages system;
        in
        packages // { default = packages.orca; }
      );

      # Consume all packages as an overlay: pkgs.{orca,rtk,...}
      overlays.default = final: prev: mkPackages final.stdenv.hostPlatform.system;

      # NUR-style non-flake access: nix-build / import ./default.nix
      legacyPackages = forAllSystems mkPackages;

      checks = forAllSystems (system: self.packages.${system});

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
