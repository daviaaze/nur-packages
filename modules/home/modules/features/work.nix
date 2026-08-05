{
  pkgs,
  lib,
  config,
  self,
  ...
}:
with lib;
{
  imports = [
    ../../../shared
  ];
  options.features.home.work = {
    enable = mkEnableOption "work-specific applications and configurations";
  };

  config = mkIf config.features.home.work.enable {
    # Enable shared modules
    shared.packages.enable = mkDefault true;
    sops.secrets = {
      work_npm_token = {
        sopsFile = "${self}/modules/secrets/work-secrets.yaml";
      };
      github_token = { };
      atlasian_api_token = {
        sopsFile = "${self}/modules/secrets/work-secrets.yaml";
      };
      datadog_api_key = {
        sopsFile = "${self}/modules/secrets/work-secrets.yaml";
      };
      circleci_api_key = {
        sopsFile = "${self}/modules/secrets/work-secrets.yaml";
      };
    };

    home.sessionVariables = {
      NPM_TOKEN = "$(cat ${config.sops.secrets.work_npm_token.path})";
      JIRA_URL = "https://aussiecommerce.atlassian.net";
      JIRA_EMAIL = "davi.azevedo@luxuryescapes.com";
      JIRA_API_TOKEN = "$(cat ${config.sops.secrets.atlasian_api_token.path})";
      CFL_URL = "https://aussiecommerce.atlassian.net/wiki";
      CFL_EMAIL = "davi.azevedo@luxuryescapes.com";
      CFL_API_TOKEN = "$(cat ${config.sops.secrets.atlasian_api_token.path})";
      DD_SITE= "ap2.datadoghq.com";
      DD_ACCESS_TOKEN = "$(cat ${config.sops.secrets.datadog_api_key.path})";
      CIRCLECI_CLI_TOKEN = "$(cat ${config.sops.secrets.circleci_api_key.path})";

      # pi-knowledge (AI knowledge base)
      PI_KNOWLEDGE_DIR = "${config.home.homeDirectory}/.pi/agent-work/knowledge";
      PI_KNOWLEDGE_EMBEDDING = "local:multilingual-e5-small";
      PI_KNOWLEDGE_AUTO_INJECT = "true";
      PI_KNOWLEDGE_WATCH = "true";
      PI_KNOWLEDGE_ENABLE_NATIVE_IDLE_DISPOSE = "true";
      PI_KNOWLEDGE_EMBEDDING_IDLE_MS = "300000";
      PI_KNOWLEDGE_SEARCH_PROFILE = "auto";
      PI_KNOWLEDGE_STALE_INDEXING_MS = "86400000";
    };

    home.sessionPath = [
      "${config.home.homeDirectory}/.pi/agent-work/bin"
    ];

    home.file.".pi/agent-work/bin/pi-work" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        export PI_CODING_AGENT_DIR="$HOME/.pi/agent-work"
        exec ${pkgs.pi-coding-agent}/bin/pi "$@"
      '';
    };

    sops.templates.".npmrc" = {
      content = ''
        //registry.npmjs.org/:_authToken=${config.sops.placeholder.work_npm_token}
      '';
      path = "${config.home.homeDirectory}/.npmrc";
    };

    sops.templates.".openfortivpn/config" = {
      content = ''
        host = vpn.luxuryescapes.com
        port = 10443
        trusted-cert = 7e6b1eec9638f5cae43f802a72fe9dfd93f5f6796a0326cab0d56c10445d481b
        # Use cookie-based authentication (no password prompt)
        cookie-on-stdin = true
        # Disable auto-reconnect to prevent infinite loops
        max-retries = 0
        # Disable DNS updates to avoid conflicts
        no-dns = true
        # Disable IPv6 to avoid routing issues
        no-ipv6 = true
        # Disable file-based authentication
        file-based-auth = false
        # Disable user-specific configuration
        user-config = false
      '';
      path = "${config.home.homeDirectory}/.openfortivpn/config";
    };

    programs.ssh.enableDefaultConfig = lib.mkDefault false;
    programs.ssh.settings."10.100.9.51" = {
      hostname = "10.100.9.51";
      controlMaster = "no";
    };

    home.packages =
      with config.shared.packages.categories.work;
      communication ++ development ++ databases ++ office ++ vpn ++ browsers;
  };
}
