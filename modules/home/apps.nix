{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ciznia.apps.enable = lib.mkEnableOption "graphical apps (browser, chat, music, image editing)";

  config = lib.mkIf config.ciznia.apps.enable {
    home.packages = with pkgs; [
      firefox
      thunderbird
      discord
      teams-for-linux
      spotify
      gimp
      peek
      pamixer
      pavucontrol
    ];
  };
}
