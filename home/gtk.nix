{ pkgs, ... }:
{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };

  # catppuccin = {
  #   gtk = {
  #     enable = true;
  #     tweaks = [ "rimless" ];
  #     size = "compact";
  #   };
  # };

  # gtk = {
  #   enable = true;

  #   cursorTheme = {
  #     name = "Catppuccin-Macchiato-Dark";
  #     package = pkgs.catppuccin-cursors.macchiatoDark;
  #   };

  #   iconTheme = {
  #     name = "Papirus-Dark";
  #     package = pkgs.papirus-icon-theme;
  #   };
  # };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };
}
