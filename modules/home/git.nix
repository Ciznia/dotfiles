{
  config,
  lib,
  pkgs,
  ...
}: {
  # git + gpg live behind one flag: signed commits need the key, the agent, and
  # a pinentry, so enabling git pulls all of it in.
  options.ciznia.git.enable = lib.mkEnableOption "git (with gpg signing + agent)";

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

      # Sign every commit/tag with the GPG identity restored by the Ansible
      # preflight (fingerprint from `gpg --show-keys`).
      signing = {
        key = "A8A7205E2FD4672A77058657654E6EA7882F6671";
        signByDefault = true;
      };
    };

    programs.gpg.enable = true;

    # home-manager only exports SSH_AUTH_SOCK (and GPG_TTY) from shells it
    # manages; unmanaged, a login bash never learns about gpg-agent's ssh socket
    # ("Could not open a connection to your authentication agent").
    programs.bash.enable = true;

    # gpg-agent configured here (home-manager), NOT via the NixOS
    # programs.gnupg.agent — so it behaves identically on standalone hosts and
    # the two never fight over the socket. It also doubles as the ssh-agent
    # (exports SSH_AUTH_SOCK) and is what the Ansible `--tags agent` flow presets.
    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;

      # Terminal pinentry — works on WSL and headless. The desktop host can
      # override this to a graphical pinentry later.
      pinentry.package = pkgs.pinentry-curses;

      # Enter the passphrase ~once per session; presets/keys stay cached.
      defaultCacheTtl = 86400;
      maxCacheTtl = 86400;
      defaultCacheTtlSsh = 86400;
      maxCacheTtlSsh = 86400;

      # Required by the Ansible agent flow:
      #   allow-preset-passphrase → gpg-preset-passphrase loads the gpg
      #                             passphrase from the vault (no prompt)
      #   allow-loopback-pinentry → scripted gpg (key export/import) in
      #                             loopback mode
      extraConfig = ''
        allow-preset-passphrase
        allow-loopback-pinentry
      '';
    };
  };
}
