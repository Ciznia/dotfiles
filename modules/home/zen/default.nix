{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.ciznia.zen;
  inherit (pkgs.stdenv.hostPlatform) system;
  addons = inputs.firefox-addons.packages.${system};

  # Not in rycee's set: our own package, written like theirs (nixpkgs style).
  mal-sync = pkgs.callPackage ./mal-sync {
    inherit (inputs.firefox-addons.lib.${system}) buildFirefoxXpiAddon;
  };
in {
  # Zen (zen-browser-flake), the default browser while trying it out; Firefox
  # stays installed. Extensions are pinned packages and settings live here, so
  # both come from Nix like VS Code's. On WSL it opens through WSLg.
  options.ciznia.zen.enable = lib.mkEnableOption "Zen browser, extensions and settings from Nix";

  config = lib.mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = true;

      # gopass-bridge talks to gopass through this native messaging host.
      nativeMessagingHosts = [pkgs.gopass-jsonapi];

      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisableAppUpdate = true; # updates come with the flake
        DontCheckDefaultBrowser = true;
        OfferToSaveLogins = false; # gopass holds the passwords
        PasswordManagerEnabled = false;
      };

      profiles.default = {
        isDefault = true;

        extensions.packages = [
          addons.ublock-origin
          addons.gopass-bridge
          mal-sync
        ];

        # catppuccin/zen-browser, like the rest of the repo (theme.nix).
        presets.catppuccin = {
          enable = true;
          flavor = "Macchiato";
          accent = "Blue";
        };

        settings = {
          # Extensions installed by Nix start enabled, without the prompt.
          "extensions.autoDisableScopes" = 0;
        };
      };
    };
  };
}
