{
  description = "daviaaze's NUR-style package collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Work-specific (private). Override with `follows` in consumer flakes
    # that have their own access to this repo.
    lux-cli = {
      url = "git+ssh://git@github.com/lux-group/cli.git?ref=main";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lux-cli,
    }:
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
          lux-cli = pkgs.callPackage ./pkgs/lux-cli/package.nix { src = lux-cli; };
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
