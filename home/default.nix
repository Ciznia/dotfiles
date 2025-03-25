{ pkgs, username, osConfig, ecsls, ehcsls, ... }:
{
  nixpkgs.config.allowUnfree = true;

  catppuccin = {
    enable = true;
    flavor = "macchiato";
    accent = "blue";
  };

  imports = [
    ./bash
    ./betterlockscreen
    ./btop
    ./dunst
    ./neofetch
    ./nvim
    ./picom
    ./qtile
    ./zsh

    ./cursor.nix
    ./extra_files.nix
    ./flameshot.nix
    ./git.nix
    ./gtk.nix
    ./kitty.nix
  ];

  xdg.configFile."xkb/symbols/us_qwerty-fr".source =
    "${pkgs.callPackage ./../system/qwerty-fr.nix {}}"
    + "/usr/share/X11/xkb/symbols/us_qwerty-fr";
  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    #keyboard = null; # using custom layout

    stateVersion = "24.05";
    sessionVariables.EDITOR = "nvim";

    packages = with pkgs; [
      # settings
      arandr
      brightnessctl

      # messaging
      discord
      teams-for-linux

      # dev
      lazygit
      llvmPackages_19.clang-tools
      ecsls.packages.${pkgs.system}.ecsls
      ehcsls.packages.${pkgs.system}.ehcsls
      nix-output-monitor
      valgrind
      nodejs
      tokei
      vscode
      wakatime
      sqlite
      insomnia

      # browsers
      firefox

      # game
      xclicker
      prismlauncher



      # misc
    ] ++ (if osConfig.services.pipewire.enable then [
      spotify
      pamixer
      pavucontrol
    ] else [ ]) ++ [
      gimp
      neofetch
      pass

      # utils
      dconf
      filterpath
      peek
      ripgrep
      unzip
      xclip
      zip
      picom
      speedtest

      rofi
      wmctrl
    ];
  };

  manual.manpages.enable = false;
  programs = {
    home-manager.enable = true;
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
