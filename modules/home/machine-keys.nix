{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.machineKeys;
  sshKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
  gpg = "${config.programs.gpg.package}/bin/gpg";

  # Asks to run scripts/machine-keys.sh while this machine has no gpg signing
  # subkey of its own. In a login shell, not at activation: the script needs
  # the Vaultwarden password, and activation has no terminal.
  check = pkgs.writeShellScript "machine-keys-check" ''
    ${gpg} --batch --with-colons --list-secret-keys ${config.ciznia.git.signingKey} 2>/dev/null |
      ${pkgs.gawk}/bin/awk -F: '$1 == "ssb" && $12 ~ /s/ && $15 != "#" { found = 1 } END { exit !found }' &&
      exit 0
    script=${cfg.repo}/scripts/machine-keys.sh
    [ -x "$script" ] || exit 0
    read -r -p "This machine has no gpg signing subkey yet. Run machine-keys now? [y/N] " answer
    case $answer in
      [yY]*) "$script" ;;
    esac
  '';
in {
  # Each machine's own identity (docs/NIX.md, Machine keys). The ssh key needs no
  # input, so activation makes it; the gpg subkey needs the master from
  # Vaultwarden, so a login shell offers to run the script.
  options.ciznia.machineKeys = {
    enable = lib.mkEnableOption "per-machine ssh key and gpg subkey prompt";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dotfiles";
      description = "Clone of this repo, where scripts/machine-keys.sh is.";
    };
  };

  config = lib.mkIf cfg.enable {
    # A link is what the old shared key (sops) left behind.
    home.activation.machineSshKey = lib.hm.dag.entryAfter ["linkGeneration"] ''
      if [ -L ${sshKey} ] || [ ! -e ${sshKey} ]; then
        run mkdir -p "$(dirname ${sshKey})"
        run chmod 700 "$(dirname ${sshKey})"
        run rm -f ${sshKey} ${sshKey}.pub
        run ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
          -C "${config.home.username}@$(${pkgs.coreutils}/bin/uname -n)" -f ${sshKey}
        echo "New ssh key for this machine, add it on GitHub (Settings > SSH keys):"
        run cat ${sshKey}.pub
      fi
    '';

    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
      [[ -o login && -t 0 ]] && ${check}
    '';
    programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
      shopt -q login_shell && [ -t 0 ] && ${check}
    '';
  };
}
