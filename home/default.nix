{ pkgs, username, ... }:
{
  nixpkgs.config.allowUnfree = true;

  imports = [
    ./nvim

    ./bash
    ./btop
    ./neofetch
    ./picom
    ./dunst
    ./qtile
    ./thunar
    ./tmux
    ./zsh

    ./betterlockscreen
    ./cursor.nix
    ./extra_files.nix
    ./flameshot.nix
    ./git.nix
    ./gtk.nix
    ./kitty.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    stateVersion = "24.05";
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # settings
      arandr
      brightnessctl

      # volume
      pavucontrol

      # messaging
      discord
      teams-for-linux

      # dev
      lazygit
      tokei
      wakatime
      zathura

      # misc
      spotify
      neofetch
      pass

      # utils
      peek
      ripgrep
      dconf
      xclip
      pamixer

      # Game
      prismlauncher
    ];
  };

  manual.manpages.enable = false;
  programs = {
    home-manager.enable = true;
    tmux.enable = true;

    bat = {
      enable = true;
      config.theme = "base16";
    };

    dircolors.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };

    feh.enable = true;
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
