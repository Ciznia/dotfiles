{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.shell;

  bash-wakatime = pkgs.fetchFromGitHub {
    owner = "gjsheep";
    repo = "bash-wakatime";
    rev = "c97292398936393c3f985f4924a3c234793ca3b8";
    hash = "sha256-Heq/VxfCqFhnYxAm2ejymANdPmZ5uNixuZiuC/53VQE=";
  };
in {
  options.ciznia.shell = {
    enable = lib.mkEnableOption "zsh + bash setup (prompt, plugins, aliases, direnv, zoxide)";

    prompt = lib.mkOption {
      type = lib.types.enum ["atomic" "sigma"];
      default = "atomic";
      description = "atomic = oh-my-posh theme (zsh + bash), sigma = oh-my-zsh theme (zsh only).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.EDITOR = "nvim";

    # The zsh and bash wakatime plugins call ~/.wakatime/wakatime-cli (the
    # official installer's path), not the one on PATH.
    # vim-wakatime downloads its own cli into ~/.wakatime and points this link at
    # it, which then fails activation as a file that would be clobbered.
    home.file.".wakatime/wakatime-cli" = {
      source = "${pkgs.wakatime-cli}/bin/wakatime-cli";
      force = true;
    };

    home.shellAliases = {
      ll = "ls -l";
      dodo = "shutdown now";
      lz = "lazygit";
      ufda = "echo 'use flake' | tee .envrc && direnv allow";
      # Build, show what changes (nvd), then switch. Runs in the current
      # directory, so ./result lands there.
      rebuild = "nix-shell -p nvd nix-output-monitor --run '
        nixos-rebuild build          \\
          --flake ~/dotfiles         \\
          --log-format internal-json \\
        |& nom --json;
        nvd diff /run/current-system result;
        sudo ./result/bin/switch-to-configuration switch'";
      update = "cd ~/dotfiles && nix flake update && rebuild; cd -";
    };

    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;

      shellAliases.cd = "z";

      plugins = [
        {
          name = "wakatime";
          src = pkgs.fetchFromGitHub {
            owner = "sobolevn";
            repo = "wakatime-zsh-plugin";
            rev = "69c6028b0c8f72e2afcfa5135b1af29afb49764a";
            hash = "sha256-pA1VOkzbHQjmcI2skzB/OP5pXn8CFUz5Ok/GLC6KKXQ=";
          };
        }
        {
          name = "zsh-autocomplete";
          src = "${pkgs.zsh-autocomplete}/share/zsh-autocomplete";
        }
      ];

      oh-my-zsh = {
        enable = true;
        custom = "${./shell/omz}";
        theme = lib.mkIf (cfg.prompt == "sigma") "sigma";
        # No ssh-agent plugin: the ssh key has no passphrase, ssh reads it directly.
        plugins = ["git" "command-not-found"];
      };
    };

    programs.oh-my-posh = lib.mkIf (cfg.prompt == "atomic") {
      enable = true;
      settings = builtins.fromJSON (builtins.readFile ./shell/atomic.omp.json);
    };

    programs.bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        ls = "ls --color=auto";
      };
      bashrcExtra = ''
        source ${bash-wakatime}/bash-wakatime.sh
      '';
    };
    home.file.".inputrc".source = ./shell/inputrc;

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    programs.zoxide.enable = true;
    programs.dircolors.enable = true;
  };
}
