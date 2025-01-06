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
  };
}
