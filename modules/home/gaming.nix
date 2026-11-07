{
  config,
  lib,
  pkgs,
  ...
}: {
  # Steam is system-level (modules/nixos/gaming.nix).
  options.ciznia.gaming.enable = lib.mkEnableOption "games (Prism Launcher, GNOME games, xclicker)";

  config = lib.mkIf config.ciznia.gaming.enable {
    home.packages = with pkgs; [
      prismlauncher
      xclicker
      gnome-mahjongg
      gnome-mines
      gnome-sudoku
    ];
  };
}
