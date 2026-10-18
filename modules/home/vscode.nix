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

  pin = cfg.server.pin;
  # The tarball unpacked as the Windows app would: bin/<commit>/{node,bin/code-server,...}.
  # Its node is a stock glibc binary, run through nix-ld (modules/nixos/base.nix).
  pinnedServer = pkgs.runCommand "vscode-server-${pin.version}" {
    src = pkgs.fetchurl {
      name = "vscode-server-${pin.commit}.tar.gz";
      url = "https://update.code.visualstudio.com/commit:${pin.commit}/server-linux-x64/stable";
      inherit (pin) hash;
    };
  } "mkdir $out && tar xzf $src -C $out --strip-components=1";

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

    # Opt-in: the server binary itself from Nix, instead of the tarball the
    # Windows app downloads into ~/.vscode-server/bin/<commit> on first connect.
    #
    # Gain: the server is pinned and hash-checked like everything else here,
    # it's in place before the first connect (no download, works offline), and
    # a reinstall gets the same build back.
    #
    # The catch: the Windows app only talks to the server built from its own
    # commit. It looks for bin/<commit>; any other build is ignored and it
    # downloads its own again. So this pin has to follow the Windows app:
    #   - when Windows VS Code updates, the pin goes stale. Nothing breaks (the
    #     app falls back to downloading its server), but the pin stops being
    #     used until `commit`/`version`/`hash` below are bumped to the new
    #     build: the commit is in "Help > About", the hash comes from
    #       nix-prefetch-url https://update.code.visualstudio.com/commit:<commit>/server-linux-x64/stable
    #       nix hash convert --hash-algo sha256 --to sri <hash>
    #   - to stop that churn, turn off the app's auto-update on Windows
    #     ("update.mode": "none") and update it on purpose, together with the pin.
    #   - the server is a writable copy of the store path, not a link: it
    #     copies files out of its own folder and later overwrites them, which
    #     a read-only store path broke (Copilot Chat, EACCES). It costs the
    #     disk space of a second copy (~400 MB).
    #   - whenever the pin changes, the switch replaces bin/<commit>, including
    #     a server the app downloaded itself. A running server loses its files
    #     under it: reload the window after switching.
    # It's not the nixpkgs VS Code: nixpkgs lags Windows releases (1.127 here
    # while Windows is on 1.142), and both are the same Microsoft binary anyway.
    server.pin = {
      enable = lib.mkEnableOption "the VS Code server binary from Nix, pinned to the Windows app's commit";
      version = lib.mkOption {
        type = lib.types.str;
        default = "1.142.0";
        description = "Windows VS Code version the pin matches (for the store path name).";
      };
      commit = lib.mkOption {
        type = lib.types.str;
        default = "6d62b1d5dace93a33b3a6d3eca1317bd5e15bcb1";
        description = "Windows VS Code commit (Help > About); the server must be built from it.";
      };
      hash = lib.mkOption {
        type = lib.types.str;
        default = "sha256-8e4oM8YyPuA+SdRjUeg0xEgRxT0UuhePXevbhKXreHY=";
        description = "SRI hash of that commit's server-linux-x64 tarball.";
      };
    };
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
            # Kept beside the real file, which the activation below copies it to.
            # Pretty-printed, so the file and "Compare with Saved" stay readable.
            "${serverDir}/data/Machine/.settings-nix.json".source = (pkgs.formats.json {}).generate "settings.json" (serverSettings
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

      # Machine settings are a writable copy, reset to Nix's on every switch:
      # extensions and the Windows app write to them (a read-only link failed
      # with EROFS on connect). Changes made in the UI last until the next switch.
      home.activation.vscodeServerSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
        machine=${config.home.homeDirectory}/${serverDir}/data/Machine
        run rm -f $VERBOSE_ARG "$machine/settings.json"
        run install -m 644 "$machine/.settings-nix.json" "$machine/settings.json"
      '';
    })

    (lib.mkIf (cfg.server.enable && pin.enable) {
      # Copied, not linked: the server copies files out of its own folder
      # (Copilot Chat's CLI shim, into data/User/globalStorage) and later
      # overwrites those copies, which fails when they inherit the store's
      # read-only mode. A writable copy, replaced whenever the pin changes, keeps
      # the pinned build without that. The marker records which store path the
      # copy came from.
      home.activation.vscodeServerPin = lib.hm.dag.entryAfter ["linkGeneration"] ''
        dir=${config.home.homeDirectory}/${serverDir}/bin/${pin.commit}
        marker=${config.home.homeDirectory}/${serverDir}/bin/.${pin.commit}.nix
        if [ -L "$dir" ] || [ ! -d "$dir" ] || [ "$(cat "$marker" 2>/dev/null)" != ${pinnedServer} ]; then
          run rm -rf $VERBOSE_ARG "$dir"
          run mkdir -p "$(dirname "$dir")"
          run cp -r ${pinnedServer} "$dir"
          run chmod -R u+w "$dir"
          run eval "echo ${pinnedServer} > $marker"
        fi
        # Copies already made from a read-only store copy stay read-only.
        storage=${config.home.homeDirectory}/${serverDir}/data/User/globalStorage
        if [ -d "$storage" ]; then
          run find "$storage" -type f ! -perm -u+w -exec chmod u+w {} +
        fi
      '';
    })
  ];
}
