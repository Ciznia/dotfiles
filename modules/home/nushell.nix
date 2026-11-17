{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # A second interactive shell next to zsh, which stays the login shell. zoxide,
  # direnv, carapace and the oh-my-posh prompt (shell.nix) hook into it through
  # their own Nushell integrations, on by default.
  options.ciznia.nushell.enable = lib.mkEnableOption "Nushell, with carapace completions and plugins";

  config = lib.mkIf config.ciznia.nushell.enable {
    programs.nushell = {
      enable = true;

      settings = {
        show_banner = false;
        history.file_format = "sqlite";
        completions.algorithm = "fuzzy";
      };

      plugins = with pkgs.nushellPlugins; [
        formats # from/to ini, plist, eml, ics, vcf
        gstat # git status of the current repo as a record
        query # query json/xml/web
      ];

      # Home Manager copies home.shellAliases here too; these two use bash
      # syntax (&&, |&), so Nushell gets them as commands below instead.
      shellAliases = lib.mkForce (
        removeAttrs config.home.shellAliases ["rebuild" "update"]
        // {cd = "z";}
      );

      # ufda's own module (its completions) instead of the package's script.
      extraConfig = ''
        use ${inputs.ufda.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/ufda
        def rebuild [] { bash -c r#'${config.home.shellAliases.rebuild}'# }
        # Not `update`: that would shadow Nushell's own `update` (tables, records)
        # in every module this file loads, jj-ci's among them.
        def upgrade [] { do { cd ~/dotfiles; nix flake update; rebuild } }
      '';
    };

    programs.carapace = {
      enable = true;
      # zsh and bash keep their own completion setup.
      enableZshIntegration = false;
      enableBashIntegration = false;
    };
  };
}
