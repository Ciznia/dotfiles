{ ... }:
{
  home.file = {
    xinitrc = {
      source = ./../.xinitrc;
      target = ".xinitrc";
    };

    wallpaper = {
      source = ./../assets/wallpaper.jpeg;
      target = "assets/wallpaper.jpeg";
    };
    lazygit = {
      text = ''
        git:
          overrideGpg: true
      '';
      target = ".config/lazygit/config.yml";
    };
  };
}
