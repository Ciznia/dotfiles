{
  config,
  lib,
  pkgs,
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

      # Home Manager copies home.shellAliases here too; these three use bash
      # syntax (&&, |&), so Nushell gets them as commands below instead.
      shellAliases = lib.mkForce (
        removeAttrs config.home.shellAliases ["ufda" "rebuild" "update"]
        // {cd = "z";}
      );

      extraConfig = ''
        def ufda [] { "use flake" | save --force .envrc; direnv allow }
        def rebuild [] { bash -c r#'${config.home.shellAliases.rebuild}'# }
        def update [] { do { cd ~/dotfiles; nix flake update; rebuild } }
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
