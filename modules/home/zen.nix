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

  # Not in rycee's set: built the same way, pinned to the AMO release.
  mal-sync = inputs.firefox-addons.lib.${system}.buildFirefoxXpiAddon {
    pname = "mal-sync";
    version = "0.12.5";
    addonId = "{c84d89d9-a826-4015-957b-affebd9eb603}";
    url = "https://addons.mozilla.org/firefox/downloads/file/4999907/mal_sync-0.12.5.xpi";
    sha256 = "5ee3c2a032d4605ec884ef7f9dee62716cb33bf467b8f03640d3610ce63190a1";
    meta = {
      homepage = "https://malsync.moe";
      description = "Syncs anime and manga progress with MyAnimeList, AniList, Kitsu and others";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.all;
    };
  };
in {
  # Zen (zen-browser-flake), next to Firefox while trying it out: Firefox stays
  # the default browser. Extensions are pinned packages, settings live here, so
  # both come from Nix like VS Code's. On WSL it opens through WSLg.
  options.ciznia.zen.enable = lib.mkEnableOption "Zen browser, extensions and settings from Nix";

  config = lib.mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
      setAsDefaultBrowser = false;

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
