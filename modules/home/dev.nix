{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.dev.enable = lib.mkEnableOption "development tools (editors, nix tooling, language runtimes)";

  config = lib.mkIf config.ciznia.dev.enable {
    home.packages = with pkgs; [
      vscode
      insomnia
      tokei
      wakatime-cli # also feeds the zsh/bash/nvim wakatime plugins
      sqlite

      llvmPackages_19.clang-tools
      valgrind
      nodejs
      (callPackage ./pkgs/ghcup.nix {})

      nil
      nix-index
      nix-output-monitor
      nixpkgs-review
    ];

    programs.lazygit = {
      enable = true;
      settings.git.overrideGpg = true;
    };
  };
}
