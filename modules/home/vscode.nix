{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.vscode;
  # Marketplace builds matched to the VS Code version, for what nixpkgs lacks.
  marketplace = (pkgs.forVSCodeVersion pkgs.vscode.version).vscode-marketplace;

  settings = builtins.fromJSON (builtins.readFile ./vscode/settings.json);

  # nixpkgs first (some are patched to run on NixOS), the marketplace for the
  # rest. Language stacks that belong to one project come from that project's
  # flake, not here.
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

  # Settings that only the app's window reads; the server ignores them.
  uiOnly = name:
    lib.any (prefix: lib.hasPrefix prefix name) [
      "workbench."
      "window."
      "terminal.integrated"
      "explorer.confirm"
      "chat."
    ];
  serverSettings = lib.filterAttrs (name: _: !uiOnly name) settings;

  serverDir = ".vscode-server";
  extensionDir = "${serverDir}/extensions";
in {
  # VS Code with its settings and extensions owned by Nix, so changes go through
  # this file, not the UI.
  options.ciznia.vscode = {
    # Native hosts: the Linux app, settings.json a read-only link, the
    # extensions dir immutable.
    enable = lib.mkEnableOption "VS Code, settings and extensions from Nix";

    # Both themes and both icon sets stay installed: changing this and
    # switching is all it takes to flip between them.
    theme = lib.mkOption {
      type = lib.types.enum ["catppuccin" "github"];
      default = "catppuccin";
      description = "catppuccin = Macchiato, blue accent, catppuccin icons; github = GitHub Dark Colorblind, vscode-icons.";
    };

    # WSL hosts: VS Code is the Windows app, which Nix doesn't reach. What it
    # runs on this side is the server it installs in ~/.vscode-server, so the
    # settings minus the UI-only ones become the server's Machine settings and
    # the extensions are linked into its extensions dir. Themes run in the
    # Windows app, so they aren't linked.
    server.enable = lib.mkEnableOption "settings and extensions for the VS Code server (WSL)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # catppuccin/nix adds the catppuccin theme (built with the macchiato
      # flavor and blue accent from theme.nix) and its icons, and selects them.
      catppuccin.vscode.profiles.default = {
        enable = true;
        icons.enable = true;
      };

      programs.vscode = {
        enable = true;
        package = pkgs.vscode;
        mutableExtensionsDir = false;

        profiles.default = {
          enableUpdateCheck = false;
          enableExtensionUpdateCheck = false;
          userSettings = lib.mkMerge [
            settings
            (lib.mkIf (cfg.theme == "github") {
              "workbench.colorTheme" = lib.mkForce "GitHub Dark Colorblind (Beta)";
              "workbench.iconTheme" = lib.mkForce "vscode-icons";
            })
          ];
          extensions =
            extensions
            ++ (with pkgs.vscode-extensions; [
              github.github-vscode-theme
              vscode-icons-team.vscode-icons
            ]);
        };
      };
    })

    (lib.mkIf cfg.server.enable {
      home.file = lib.mkMerge (
        [
          {
            "${serverDir}/data/Machine/settings.json".text = builtins.toJSON (serverSettings
              // {
                # The linked extensions are read-only store paths.
                "extensions.autoUpdate" = false;
              });

            # The server tracks installed extensions in extensions.json. Linked
            # folders missing from it are ignored, so when the Nix set changes,
            # drop it: the next server start rescans the dir, keeping extensions
            # the Windows app installed there, and writes it again.
            "${extensionDir}/.extensions-nix.json" = {
              text = pkgs.vscode-utils.toExtensionJson extensions;
              onChange = ''
                run rm $VERBOSE_ARG -f ${config.home.homeDirectory}/${extensionDir}/extensions.json
              '';
            };
          }
        ]
        ++ map (ext: {
          "${extensionDir}/${ext.vscodeExtUniqueId}".source = "${ext}/share/vscode/extensions/${ext.vscodeExtUniqueId}";
        })
        extensions
      );
    })
  ];
}
