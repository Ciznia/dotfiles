{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.dev.enable = lib.mkEnableOption "development tools (editors, nix tooling, language runtimes)";

  config = lib.mkIf config.ciznia.dev.enable {
    home.packages = with pkgs; [
      insomnia
      tokei
      wakatime-cli # also feeds the zsh/bash/nvim wakatime plugins
      sqlite

      llvmPackages_19.clang-tools
      valgrind
      nodejs
      (callPackage ./pkgs/ghcup.nix {})

      # Outside a project's devshell, whose toolchain comes first. The wasm
      # target is what `termoxide run` builds an app's guest for.
      (rust-bin.stable.latest.default.override {
        extensions = ["rust-src"];
        targets = ["wasm32-wasip2"];
      })

      nil
      nix-index
      nix-output-monitor
      nixpkgs-review
    ];

    # What `cargo install` installs.
    home.sessionPath = ["$HOME/.cargo/bin"];

    programs.lazygit = {
      enable = true;
      settings.git.overrideGpg = true;
    };
  };
}
