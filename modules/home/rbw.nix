{
  config,
  lib,
  pkgs,
  ...
}: {
  # Vaultwarden client. Holds the offline gpg master key that
  # scripts/machine-keys.sh pulls to certify a machine's subkey.
  options.ciznia.rbw.enable = lib.mkEnableOption "rbw, the Vaultwarden CLI";

  config = lib.mkIf config.ciznia.rbw.enable {
    programs.rbw = {
      enable = true;
      settings = {
        email = "hosquetgabriel@gmail.com";
        base_url = "https://vault.hosquet.com";
        pinentry = pkgs.pinentry-curses;
      };
    };
  };
}
