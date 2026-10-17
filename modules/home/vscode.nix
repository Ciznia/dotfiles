{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.vscode;
  # Marketplace builds matched to the installed VS Code, for what nixpkgs lacks.
  marketplace = (pkgs.forVSCodeVersion config.programs.vscode.package.version).vscode-marketplace;
in {
  # VS Code with its settings and extensions owned by Nix: settings.json is a
  # read-only link and the extensions dir is immutable, so changes go through
  # this file, not the UI. On WSL hosts VS Code is the Windows app, which Nix
  # doesn't reach, so only native hosts enable this.
  options.ciznia.vscode.enable = lib.mkEnableOption "VS Code, settings and extensions from Nix";

  config = lib.mkIf cfg.enable {
    # VS Code keeps its own theme (GitHub Dark Colorblind + vscode-icons), not
    # catppuccin's.
    catppuccin.vscode.profiles.default.enable = false;

    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      mutableExtensionsDir = false;

      profiles.default = {
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;
        userSettings = builtins.fromJSON (builtins.readFile ./vscode/settings.json);

        # nixpkgs first (some are patched to run on NixOS), the marketplace
        # for the rest. Language stacks that belong to one project come from
        # that project's flake, not here.
        extensions =
          (with pkgs.vscode-extensions; [
            # Editing
            aaron-bond.better-comments
            ban.spellright
            christian-kohler.npm-intellisense
            christian-kohler.path-intellisense
            editorconfig.editorconfig
            esbenp.prettier-vscode
            formulahendry.code-runner
            mechatroner.rainbow-csv
            natqe.reload
            nhoizey.gremlins
            oderwat.indent-rainbow
            shardulm94.trailing-spaces
            usernamehw.errorlens
            zainchen.json

            # Look
            github.github-vscode-theme
            vscode-icons-team.vscode-icons

            # Git and GitHub
            eamodio.gitlens
            github.vscode-github-actions
            github.vscode-pull-request-github

            # Docs and data
            davidanson.vscode-markdownlint
            redhat.vscode-yaml
            tamasfe.even-better-toml
            tomoki1207.pdf
            unifiedjs.vscode-mdx
            yzhang.markdown-all-in-one
            cweijan.dbclient-jdbc
            cweijan.vscode-database-client2
            humao.rest-client

            # Nix
            jnoortheen.nix-ide
            mkhl.direnv

            # Languages
            astro-build.astro-vscode
            dbaeumer.vscode-eslint
            fill-labs.dependi
            ms-python.debugpy
            ms-python.python
            ms-python.vscode-pylance
            ms-python.vscode-python-envs
            ms-vscode.cmake-tools
            ms-vscode.cpptools
            ms-vscode.makefile-tools
            rust-lang.rust-analyzer
            vadimcn.vscode-lldb
            redhat.java
            vscjava.vscode-gradle
            vscjava.vscode-java-debug
            vscjava.vscode-java-dependency
            vscjava.vscode-java-pack
            vscjava.vscode-java-test
            vscjava.vscode-maven

            # Remote and collaboration
            ms-azuretools.vscode-containers
            ms-vscode-remote.remote-containers
            ms-vscode-remote.remote-ssh
            ms-vsliveshare.vsliveshare
            wakatime.vscode-wakatime
          ])
          ++ (with marketplace; [
            alefragnani.rtf
            awxxxxxx.vscode-mdx-checker
            batchnepal.vscode-video-preview
            bradleycamacho.docs-extensions
            chakrounanas.turbo-console-log
            chrischinchilla.vale-vscode
            chrisdias.vscode-opennewinstance
            codestream.codestream
            fnando.linter
            gingerturtle.html-preview-pro
            hajdaini.select-until-pattern
            iulian-radu-at.find-unused-exports
            jkjustjoshing.vscode-text-pastry
            juanallo.vscode-dependency-cruiser
            kirozen.wordcounter
            ms-sarifvscode.sarif-viewer
            ms-vscode.cpp-devtools
            naco-siren.gradle-language
            oouo-diogo-perdigao.docthis
            qwtel.sqlite-viewer
            sanjulaganepola.github-local-actions
            techer.open-in-browser
            vivaxy.vscode-conventional-commits
            wmanth.jar-viewer
          ]);
      };
    };
  };
}
