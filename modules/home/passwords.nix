{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ciznia.passwords;
  gopass = lib.getExe pkgs.gopass;
  root = "${config.xdg.dataHome}/gopass/stores/root";
  # machine-keys.nix writes it once this machine's keys exist: the clone needs
  # the ssh key on GitHub and the encryption subkey.
  keysStamp = "${config.xdg.stateHome}/machine-keys/done";

  clones = lib.concatStringsSep " && " (
    ["${gopass} clone ${cfg.root}"]
    ++ lib.mapAttrsToList (mount: url: "${gopass} clone ${url} ${mount}") cfg.mounts
  );

  # Offers to clone the stores while this machine has none, once its keys are
  # set up. gopass then keeps them synced itself (core.autosync).
  check = pkgs.writeShellScript "passwords-check" ''
    [ -d ${root} ] && exit 0
    [ -e ${keysStamp} ] || exit 0
    read -r -p "No password store on this machine yet. Clone it now? [y/N] " answer
    case $answer in
      [yY]*) ${clones} ;;
    esac
  '';
in {
  options.ciznia.passwords = {
    enable = lib.mkEnableOption "gopass, with its stores cloned from a login prompt";

    root = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:Ciznia/passwords.git";
      description = "Root store.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {termoxide = "git@github.com:TermOxide/.password-store.git";};
      description = "Stores mounted under the root, by mount name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.gopass];
    home.shellAliases.pass = "gopass";

    # After the machine-keys prompt, which writes the stamp.
    programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (lib.mkAfter ''
      [[ -t 0 ]] && ${check}
    '');
    programs.bash.initExtra = lib.mkIf config.programs.bash.enable (lib.mkAfter ''
      [ -t 0 ] && ${check}
    '');
  };
}
