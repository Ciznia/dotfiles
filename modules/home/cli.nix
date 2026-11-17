{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.cli.enable = lib.mkEnableOption "everyday CLI tools (btop, neofetch, ripgrep, ...)";

  config = lib.mkIf config.ciznia.cli.enable {
    home.packages = with pkgs; [
      btop
      # neofetch left nixpkgs (unmaintained); hyfetch ships its maintained fork,
      # neowofetch, which reads the same ~/.config/neofetch/config.conf.
      hyfetch
      filterpath
      jq
      ripgrep
      speedtest
      tree
      unzip
      wget
      zip
    ];
    home.shellAliases.neofetch = "neowofetch";

    xdg.configFile = {
      "btop/btop.conf".source = ./cli/btop.conf;
      "neofetch/config.conf".source = ./cli/neofetch.conf;
    };
  };
}
