{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.claude;
  win = cfg.windows;
  winContext = pkgs.writeText "claude-windows-CLAUDE.md" (
    builtins.readFile ./CLAUDE.md + lib.optionalString (win.context != "") "\n${win.context}"
  );
  settingsFile = (pkgs.formats.json {}).generate "claude-settings.json" config.programs.claude-code.settings;
in {
  options.ciznia.claude = {
    enable = lib.mkEnableOption "Claude Code cli and its global config";

    windows = {
      enable = lib.mkEnableOption "the same config for the Windows-side Claude of a WSL host";
      configDir = lib.mkOption {
        type = lib.types.str;
        example = "/mnt/c/Users/me/.claude";
        description = "The Windows `.claude` directory, seen from WSL.";
      };
      context = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Appended to the shared CLAUDE.md on the Windows side only.";
      };
    };
  };

  # Only config lives here: transcripts, memory, credentials and the app-synced
  # skills/synced stay Claude Code's own state in ~/.claude and ~/.claude.json.
  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      context = ./CLAUDE.md;

      # Claude Code writes settings.json itself (permission grants, /config);
      # mutable keeps it writable and merges these keys in at each switch.
      mutableSettings = true;
      settings = {
        theme = "dark";
        agentPushNotifEnabled = true;
        attribution = {
          commit = "";
          pr = "";
        };
        extraKnownMarketplaces.claude-plugins-official.source = {
          source = "github";
          repo = "anthropics/claude-plugins-official";
        };
      };
    };

    # Copies, not links: Windows can't follow a link into the WSL Nix store.
    home.activation.claudeWindows = lib.mkIf win.enable (
      lib.hm.dag.entryAfter ["linkGeneration"] ''
        if [[ -d ${lib.escapeShellArg (dirOf win.configDir)} ]]; then
          run mkdir -p ${lib.escapeShellArg win.configDir}
          run cp --no-preserve=mode ${winContext} ${lib.escapeShellArg "${win.configDir}/CLAUDE.md"}
          ${lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          path = "${win.configDir}/settings.json";
          staticSettings = settingsFile;
          format = "json";
          empty = "{}";
          jqOperation = "$dynamic * $static";
        }}
        else
          warnEcho ${lib.escapeShellArg "${dirOf win.configDir} is missing (Windows drive not mounted?); skipping the Windows-side Claude config."}
        fi
      ''
    );
  };
}
