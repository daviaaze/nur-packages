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
