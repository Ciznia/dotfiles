{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.machineKeys;
  sshKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
  gpg = "${config.programs.gpg.package}/bin/gpg";

  # Asks to run scripts/machine-keys.sh while this machine lacks its own ssh key
  # (none, or the old shared one's sops link) or its own gpg signing subkey.
  # The script makes both in one go, so they reach GitHub together. In a login
  # shell, not at activation: it needs the Vaultwarden password, and activation
  # has no terminal.
  check = pkgs.writeShellScript "machine-keys-check" ''
    if [ -f ${sshKey} ] && [ ! -L ${sshKey} ] &&
      ${gpg} --batch --with-colons --list-secret-keys ${config.ciznia.git.signingKey} 2>/dev/null |
      ${pkgs.gawk}/bin/awk -F: '$1 == "ssb" && $12 ~ /s/ && $15 != "#" { found = 1 } END { exit !found }'; then
      exit 0
    fi
    script=${cfg.repo}/scripts/machine-keys.sh
    [ -x "$script" ] || exit 0
    read -r -p "This machine has no ssh key or gpg signing subkey of its own yet. Run machine-keys now? [y/N] " answer
    case $answer in
      [yY]*) "$script" ;;
    esac
  '';
in {
  # Each machine's own identity (docs/NIX.md, Machine keys).
  options.ciznia.machineKeys = {
    enable = lib.mkEnableOption "the login prompt to make this machine's ssh key and gpg subkey";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/dotfiles";
      description = "Clone of this repo, where scripts/machine-keys.sh is.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable ''
      [[ -o login && -t 0 ]] && ${check}
    '';
    programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
      shopt -q login_shell && [ -t 0 ] && ${check}
    '';
  };
}
