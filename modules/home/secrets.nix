{
  config,
  lib,
  ...
}: let
  cfg = config.ciznia.secrets;
  home = config.home.homeDirectory;
in {
  # Tokens decrypted by sops-nix from secrets/secrets.yaml. Only enable on a
  # machine whose age key is a recipient in .sops.yaml (see docs/NIX.md, Secrets),
  # or sops-nix.service fails to decrypt. ssh and gpg keys are per machine and
  # never in here (scripts/machine-keys.sh).
  options.ciznia.secrets = {
    enable = lib.mkEnableOption "sops-nix secrets";
    # Separate: sops-nix fails the whole service when a declared secret is
    # missing from the file, so only turn it on once wakatime_api_key is in it.
    wakatime.enable = lib.mkEnableOption "the WakaTime API key from sops";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Not age.generateKey: it would hide a missing key behind a fresh one that
      # no .sops.yaml recipient matches.
      sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      sops.defaultSopsFile = ../../secrets/secrets.yaml;
    }

    (lib.mkIf cfg.wakatime.enable {
      sops.secrets.wakatime_api_key = {};

      # The zsh, bash and nvim wakatime plugins all read the key from here.
      sops.templates."wakatime.cfg" = {
        path = "${home}/.wakatime.cfg";
        content = ''
          [settings]
          api_key = ${config.sops.placeholder.wakatime_api_key}
        '';
      };
    })
  ]);
}
