# Package categories system for organized package management
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
{
  options.shared.packages = {
    enable = mkEnableOption "shared package categories system";

    categories = mkOption {
      type = types.attrsOf (types.attrsOf (types.listOf types.package));
      default = { };
      description = "Package categories organized by domain and subcategory";
    };
  };

  config = mkIf config.shared.packages.enable {
    shared.packages.categories = {
      # Desktop applications
      desktop = {
        # core — reserved for future use (see wm-configs/kitty for kitty)
        core = with pkgs; [ ];

        productivity = with pkgs; [
          obsidian
          bitwarden-desktop
        ];

        utilities = with pkgs; [
          vial
          solaar
          gnome-disk-utility
          qalculate-gtk
          overskride
          vesktop
          mission-center
          trayscale
          batteryscope
          orca
        ];

        design = with pkgs; [
          penpot-desktop
          krita
        ];

        theming = with pkgs; [
          inter
        ];
      };

      # Development tools
      development = {
        nix = with pkgs; [
          nix-index
          nix-ld
          nixd
          nixfmt
          devenv
        ];

        editors = with pkgs; [
          micro
          zed-editor
        ];

        version-control = with pkgs; [
          git
          gh
        ];
      };

      # CLI tools
      cli = {
        core = with pkgs; [
          btop
          screen
          tmux
          bc
          bat
          eza
          fzf
          jq
          lm_sensors
          nethogs
          powertop
          python3
        ];

        development = with pkgs; [
          pi-coding-agent
          opencode
          opencli
          zed-editor
        ];
      };

      # Media applications
      media = {
        streaming = with pkgs; [
          spotify
          stremio-linux-shell
        ];

        remote = with pkgs; [
          moonlight-qt
        ];
      };

      # Work applications
      work = {
        communication = with pkgs; [
          slack
          teams-for-linux
        ];

        development = with pkgs; [
          postman
          lux-cli
          pup
          atlassian-cli
          circleci-cli
          codex
          cursor-cli
          code-cursor
        ];

        databases = with pkgs; [
          postgresql
          sqlite-jdbc
          dbeaver-bin
        ];

        office = with pkgs; [
          libreoffice
        ];

        vpn = with pkgs; [
          openfortivpn
          openfortivpn-webview
        ];

        browsers = with pkgs; [
          google-chrome
        ];
      };
    };
  };
}
