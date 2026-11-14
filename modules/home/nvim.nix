{
  config,
  lib,
  pkgs,
  ...
}: {
  # Neovim with lazy.nvim: plugins are pinned by lua/lazy-lock.json and fetched
  # by lazy at first start, not by nix. LSP servers come from nix.
  options.ciznia.nvim.enable = lib.mkEnableOption "neovim (lazy.nvim config + LSP servers)";

  config = lib.mkIf config.ciznia.nvim.enable {
    # lazy.nvim already loads catppuccin/nvim (lua/plugins/colorscheme.lua).
    catppuccin.nvim.enable = false;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      extraConfig = builtins.readFile ./nvim/vimrc;
      plugins = [pkgs.vimPlugins.lazy-nvim];
      extraPackages = with pkgs; [
        nil
        lua-language-server
        pyright
        clang-tools
        llvmPackages_latest.clang
        haskell-language-server
        nodejs
        xclip
      ];
    };

    xdg.configFile."nvim/lua".source = ./nvim/lua;

    # lazy.nvim rewrites its lockfile on update, so it can't be a read-only
    # store link: seed it once instead.
    home.activation.nvimLazyLock = lib.hm.dag.entryAfter ["writeBoundary"] ''
      lock="${config.xdg.configHome}/nvim/lazy-lock.json"
      if [ ! -e "$lock" ]; then
        run install -Dm644 ${./nvim/lazy-lock.json} "$lock"
      fi
    '';
  };
}
