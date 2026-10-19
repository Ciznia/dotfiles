{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.fonts.enable = lib.mkEnableOption "font set (nerd fonts, noto, CJK, emoji)";

  config = lib.mkIf config.ciznia.fonts.enable {
    fonts.packages = with pkgs; [
      apl386
      fira-code
      fira-code-symbols
      liberation_ttf
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg # kitty's font
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      proggyfonts
    ];
  };
}
