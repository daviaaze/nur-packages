{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  testers,
  atlassian-cli,
}:
buildGoModule rec {
  pname = "atlassian-cli";
  version = "unstable-2026-05-06";

  src = fetchFromGitHub {
    owner = "open-cli-collective";
    repo = "atlassian-cli";
    rev = "dd46029010b165a182a17901008fe97ef884d42a";
    hash = "sha256-Gzw5uDrBSynscEXr+J4dajGMwSEfGlV6gVUH+smxJYU=";
  };

  vendorHash = "sha256-NE41eRTaEox2E6Qh26jq0pgbs+xp94GiYwgUw71VkTg=";

  # Vendor FOD must use 'go work vendor' because this is a Go workspace
  overrideModAttrs = old: {
    buildPhase = ''
      runHook preBuild
      go work vendor
      runHook postBuild
    '';
  };

  subPackages = [
    "tools/jtk/cmd/jtk"
    "tools/cfl/cmd/cfl"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  nativeBuildInputs = [ installShellFiles ];

  postInstall = ''
    for tool in jtk cfl; do
      installShellCompletion --cmd $tool \
        --bash <($out/bin/$tool completion bash) \
        --zsh <($out/bin/$tool completion zsh) \
        --fish <($out/bin/$tool completion fish)
    done
  '';

  passthru.tests.version = testers.testVersion {
    package = atlassian-cli;
    command = "jtk --version";
  };

  meta = with lib; {
    description = "CLI tools for Atlassian products — Jira (jtk) and Confluence (cfl)";
    longDescription = ''
      atlassian-cli provides unified CLI tools for Atlassian Cloud products:

      - **jtk** — Jira CLI: manage issues, sprints, boards, comments,
        attachments, dashboards, automation rules, and more
      - **cfl** — Confluence CLI: markdown-first page management, search,
        spaces, and attachments
    '';
    homepage = "https://github.com/open-cli-collective/atlassian-cli";
    changelog = "https://github.com/open-cli-collective/atlassian-cli/releases";
    license = licenses.mit;
    mainProgram = "jtk";
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
