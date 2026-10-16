{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.secrets;
  home = config.home.homeDirectory;
  gpg = "${config.programs.gpg.package}/bin/gpg";
  inherit (config.ciznia.git) signingKey;
in {
  # Each machine's own ssh and gpg keys, decrypted by sops-nix from
  # secrets/<host>.yaml, which only that machine's age key opens. Only enable on a
  # machine that has its file and is its recipient in .sops.yaml (see docs/NIX.md,
  # Secrets), or sops-nix.service fails to decrypt.
  options.ciznia.secrets = {
    enable = lib.mkEnableOption "sops-nix secrets (this machine's ssh and gpg keys)";

    host = lib.mkOption {
      type = lib.types.str;
      description = "Machine name: its keys are read from secrets/<host>.yaml.";
    };

    sshPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "Public half of this machine's ssh key, written to ~/.ssh/id_ed25519.pub.";
    };

    # Separate: sops-nix fails the whole service when a declared secret is
    # missing from the file, so only turn it on once wakatime_api_key is in it.
    wakatime.enable = lib.mkEnableOption "the WakaTime API key from sops (secrets/secrets.yaml, shared)";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Not age.generateKey: it would hide a missing key behind a fresh one that
      # no .sops.yaml recipient matches.
      sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
      sops.defaultSopsFile = ../../secrets + "/${cfg.host}.yaml";

      # Decrypted into $XDG_RUNTIME_DIR (tmpfs), each `path` is a symlink to it.
      # sops-nix replaces whatever file already sits at a path.
      sops.secrets = {
        ssh_private_key.path = "${home}/.ssh/id_ed25519";
        gpg_private_key = {};
      };

      home.file.".ssh/id_ed25519.pub" = {
        # The Ansible preflight wrote this as a plain file; replace it.
        force = true;
        text = cfg.sshPublicKey + "\n";
      };

      # gpg keeps its own keyring, so the key is imported rather than linked.
      # Skipped once the signing key is present; a rotated key (new fingerprint)
      # gets imported and trusted.
      systemd.user.services.gpg-import = {
        Unit = {
          Description = "Import the GPG signing key from sops";
          After = ["sops-nix.service"];
          Requires = ["sops-nix.service"];
        };
        Service = {
          Type = "oneshot";
          Environment = "GNUPGHOME=${config.programs.gpg.homedir}";
          ExecStart = toString (pkgs.writeShellScript "gpg-import" ''
            ${gpg} --list-secret-keys ${signingKey} >/dev/null 2>&1 && exit 0
            ${gpg} --batch --import ${config.sops.secrets.gpg_private_key.path}
            echo "${signingKey}:6:" | ${gpg} --import-ownertrust
          '');
        };
        Install.WantedBy = ["default.target"];
      };
    }

    (lib.mkIf cfg.wakatime.enable {
      # The same token on every machine, so it lives in the shared file.
      sops.secrets.wakatime_api_key.sopsFile = ../../secrets/secrets.yaml;

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
