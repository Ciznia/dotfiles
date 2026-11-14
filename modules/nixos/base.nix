{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  # What every NixOS host shares: nix settings, the login shell, man pages.
  options.ciznia.base.enable = lib.mkEnableOption "shared NixOS baseline (nix settings, zsh, man pages)";

  config = lib.mkIf config.ciznia.base.enable {
    nix = {
      settings = {
        experimental-features = ["nix-command" "flakes"];
        trusted-users = ["root" "@wheel"];
        # Keep build inputs of live outputs, so devshells survive a gc.
        keep-outputs = true;
        keep-derivations = true;
        auto-optimise-store = true;
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 90d";
      };
      optimise.automatic = true;
    };

    catppuccin = {
      enable = true;
      autoEnable = true; # theme every supported program
      flavor = "macchiato";
    };

    programs.zsh.enable = true;
    environment.shells = [pkgs.zsh];
    users.users.${username}.shell = pkgs.zsh;

    # Run unpatched binaries (VS Code server, downloaded tools).
    programs.nix-ld = {
      enable = true;
      libraries = [pkgs.glibc pkgs.zlib];
    };

    programs.command-not-found.enable = false;

    documentation.dev.enable = true;
    environment.systemPackages = with pkgs; [
      git
      tree
      neovim
      wget
      gnumake
      gcc
      man-pages
      man-pages-posix
    ];

    environment.sessionVariables = {
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
  };
}
