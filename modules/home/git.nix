{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.ciznia.git) signingKey;
in {
  # git + gpg live behind one flag: signed commits need the key, the agent, and
  # a pinentry, so enabling git pulls all of it in.
  options.ciznia.git = {
    enable = lib.mkEnableOption "git (with gpg signing + agent)";

    signingKey = lib.mkOption {
      type = lib.types.str;
      default = "A8A7205E2FD4672A77058657654E6EA7882F6671";
      # The master, without "!": gpg then signs with the newest signing subkey
      # whose secret is here, i.e. this machine's own (scripts/machine-keys.sh).
      description = "GPG key (fingerprint) that signs commits.";
    };
  };

  config = lib.mkIf config.ciznia.git.enable {
    programs.git = {
      enable = true;

      settings = {
        user.name = "ciznia";
        user.email = "hosquetgabriel@gmail.com";
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };

      # Installs git-lfs and its global filter, so clones and pulls check out the
      # real LFS files (assets/) instead of ~130-byte pointer files. A clone made
      # without it silently fed pointers to the desktop (see docs/NIX.md).
      lfs.enable = true;

      # Sign every commit/tag with that identity.
      signing = {
        key = signingKey;
        signByDefault = true;
      };
    };

    programs.gpg = {
      enable = true;
      # Bare `gpg --sign`/`--clearsign` otherwise picks the first secret key in
      # the keyring, which can be a retired one.
      settings.default-key = signingKey;
    };

    # gpg-agent configured here (home-manager), NOT via the NixOS
    # programs.gnupg.agent — so it behaves identically on standalone hosts and
    # the two never fight over the socket. Signing only: the keys carry no
    # passphrase and ssh reads ~/.ssh/id_ed25519 directly, without an agent.
    services.gpg-agent = {
      enable = true;

      # Terminal pinentry — works on WSL and headless. The desktop host can
      # override this to a graphical pinentry later.
      pinentry.package = pkgs.pinentry-curses;
    };
  };
}
