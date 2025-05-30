{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      eval "$(oh-my-posh init zsh --config ~/.poshthemes/atomic.omp.json)"
    '';
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.8.0";
          sha256 = "iJdWopZwHpSyYl5/FQXEW7gl/SrKaYDEtTH9cGP7iPo=";
        };
      }
      {
        name = "wakatime";
        src = pkgs.fetchFromGitHub {
          owner = "sobolevn";
          repo = "wakatime-zsh-plugin";
          rev = "69c6028b0c8f72e2afcfa5135b1af29afb49764a";
          sha256 = "pA1VOkzbHQjmcI2skzB/OP5pXn8CFUz5Ok/GLC6KKXQ=";
        };
      }
      {
        name = "zsh-autocomplete";
        src = pkgs.fetchFromGitHub {
          owner = "marlonrichert";
          repo = "zsh-autocomplete";
          rev = "23.07.13";
          sha256 = "0NW0TI//qFpUA2Hdx6NaYdQIIUpRSd0Y4NhwBbdssCs=";
        };
      }
    ];

    shellAliases = {
      ll = "ls -l";
      dodo = "shutdown now";
      lz = "lazygit";
      ufda = "echo 'use flake' | tee .envrc && direnv allow";
      cd = "z";
      ep = "docker run -it --rm -v $(pwd):/home/project -w /home/project epitechcontent/epitest-docker:latest /bin/bash";
      prismlauncher = "nvidia-offload prismlauncher";
      cs = "nix run github:Sigmapitech/cs";
      rebuild = "sudo ls > /dev/null; \
        sudo nixos-rebuild switch --flake ~/dotfiles -v --log-format internal-json |& nom --json";
      update = "sudo ls > /dev/null; cd ~/dotfiles && nix flake update && rebuild; cd -";
    };

    oh-my-zsh = {
      enable = true;

      custom = "$HOME/extra/zsh";
      theme = "sigma";

      plugins = [
        "git"
        "ssh-agent"
        "command-not-found"
      ];
    };
  };

  home.file.omz_zsh_theme = {
    source = ./sigma.zsh-theme;
    target = "extra/zsh/themes/sigma.zsh-theme";
  };
}
