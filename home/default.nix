{ pkgs, username, pkgs_unstable, ... }:
{
  nixpkgs.config.allowUnfree = true;

  imports = [
    ./nvim

    ./bash
    ./btop
    ./neofetch
    ./picom
    ./dunst
    ./firefox
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

    stateVersion = "22.11";
    sessionVariables = {
      EDITOR = pkgs.nano;
    };

    packages =
      let
        figma-linux-wrap = with pkgs; figma-linux.overrideAttrs (prev: {
          nativeBuildInputs = prev.nativeBuildInputs ++ [ wrapGAppsHook ];
        });

      in
      with pkgs; [
        # settings
        arandr
        brightnessctl
        lxappearance

        figma-linux-wrap

        # volume
        pamixer
        pulsemixer
        pavucontrol

        # messaging
        discord
        teams-for-linux

        # dev
        tokei
        wakatime

        # misc
        spotify
        gimp
        neofetch
        pass

        # utils
        peek
        ripgrep
        dconf
        xclip
        appimage-run

        clang-analyzer
        clang-tools_17

        pkgs_unstable.vscode

        # Games
        steam
        minecraft
      ];
  };

  programs = {
    home-manager.enable = true;

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
    lazygit.enable = true;
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
