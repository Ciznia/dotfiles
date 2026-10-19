{
  config,
  lib,
  ...
}: {
  # catppuccin/nix themes every program it knows (kitty, btop, rofi, zsh
  # syntax highlighting, ...) once it is enabled globally.
  options.ciznia.theme.enable = lib.mkEnableOption "catppuccin theme (macchiato, blue accent)";

  config = lib.mkIf config.ciznia.theme.enable {
    catppuccin = {
      enable = true;
      autoEnable = true;
      flavor = "macchiato";
      accent = "blue";
    };
  };
}
